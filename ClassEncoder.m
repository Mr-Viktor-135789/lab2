classdef ClassEncoder < handle
    % Кодирование и восстановление BBFRAME, BCH и LDPC DVB-S2.
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        NumPackets;
        LastLDPCValid = false;
        LastBCHValid = false;
        LastBBHeaderValid = false;
        LastPacketCRCValid = false;
    end
    properties (Access = private)
        BCHGenerator;
        LDPCPositions;
    end
    methods
        function obj = ClassEncoder(Params, LogLanguage)
            obj.isTransparent = Params.Encoder.isTransparent;
            obj.LogLanguage = LogLanguage;
            obj.NumPackets = Params.Source.NumTSPacketsPerFrame;
            obj.BCHGenerator = obj.makeBCHGenerator();
            obj.LDPCPositions = obj.makeLDPCPositions();
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end

            % Заменяем байт синхронизации MPEG-TS CRC предыдущего пакета.
            if size(InData, 2) ~= 188 || size(InData, 1) ~= obj.NumPackets
                error('Источник должен передать заданное число пакетов MPEG-TS по 188 байт.');
            end
            if any(InData(:, 1) ~= uint8(71))
                error('В исходном потоке обнаружен пакет MPEG-TS без байта синхронизации 0x47.');
            end
            stream = zeros(188 * obj.NumPackets, 1, 'uint8');
            previousCRC = uint8(0);
            for k = 1:obj.NumPackets
                first = (k - 1) * 188 + 1;
                payload = uint8(InData(k, 2:188)).';
                stream(first) = previousCRC;
                stream(first + 1:first + 187) = payload;
                previousCRC = obj.crc8(payload);
            end

            % Формируем BBHEADER для транспортного потока.
            dfl = numel(stream) * 8;
            header = uint8([240; 0; 5; 224; bitshift(dfl, -8); bitand(dfl, 255); 71; 0; 0]);
            header = [header; obj.crc8(header)];
            paddingBytes = 53840 / 8 - numel(header) - numel(stream);
            if paddingBytes < 0
                error('Данные не помещаются в BBFRAME команды 8.');
            end
            bbBytes = [header; stream; zeros(paddingBytes, 1, 'uint8')];
            bbBits = obj.bytesToBits(bbBytes);

            % Скремблирование BBFRAME, затем BCH- и LDPC-кодирование.
            bbBits = bitxor(bbBits, obj.makeBBScrambler(53840));
            bchWord = obj.bchEncode(bbBits);
            OutData = obj.ldpcEncode(bchWord);
        end

        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end

            % В канале без шума проверяем кодовые слова и извлекаем данные.
            [bchWord, ldpcOK] = obj.ldpcDecodeNoNoise(InData);
            obj.LastLDPCValid = ldpcOK;
            [bbScrambled, bchOK] = obj.bchDecodeNoNoise(bchWord);
            obj.LastBCHValid = bchOK;
            if ~obj.LastLDPCValid
                error('Не пройдена проверка чётности LDPC.');
            end
            if ~obj.LastBCHValid
                error('Не пройдена проверка чётности BCH.');
            end

            bbBits = bitxor(bbScrambled, obj.makeBBScrambler(53840));
            bbBytes = obj.bitsToBytes(bbBits);
            header = bbBytes(1:10);
            obj.LastBBHeaderValid = obj.crc8(header(1:9)) == header(10);
            if ~obj.LastBBHeaderValid
                error('Не пройдена CRC-8 заголовка BBFRAME.');
            end

            upl = double(header(3)) * 256 + double(header(4));
            dfl = double(header(5)) * 256 + double(header(6));
            if upl ~= 1504 || header(1) ~= 240 || header(7) ~= 71 || ...
                    header(8) ~= 0 || header(9) ~= 0 || dfl ~= obj.NumPackets * 1504
                error('Поля BBHEADER не соответствуют параметрам команды 8.');
            end

            dataField = bbBytes(11:10 + dfl / 8);
            OutData = zeros(obj.NumPackets, 188, 'uint8');
            previousPayload = uint8([]);
            obj.LastPacketCRCValid = true;
            for k = 1:obj.NumPackets
                first = (k - 1) * 188 + 1;
                marker = dataField(first);
                payload = dataField(first + 1:first + 187);
                if k == 1
                    expectedCRC = uint8(0);
                else
                    expectedCRC = obj.crc8(previousPayload);
                end
                obj.LastPacketCRCValid = obj.LastPacketCRCValid && marker == expectedCRC;
                OutData(k, :) = [uint8(71), payload.'];
                previousPayload = payload;
            end
            if ~obj.LastPacketCRCValid
                error('Не совпали CRC-маркеры транспортных пакетов MPEG-TS.');
            end
        end
    end

    methods (Access = private)
        function generator = makeBCHGenerator(~)
            % Строим порождающий полином BCH(54000, 53840), t = 10.
            m = 16; n = 2^m - 1; primitive = uint32(hex2dec('1002D'));
            expTable = zeros(n, 1, 'uint32');
            logTable = -ones(2^m, 1, 'int32');
            value = uint32(1);
            for k = 0:n-1
                expTable(k + 1) = value;
                logTable(double(value) + 1) = int32(k);
                value = bitshift(value, 1);
                if bitget(value, 17)
                    value = bitxor(value, primitive);
                end
            end

            generator = uint8(1);
            seen = false(n, 1);
            for root = 1:2:19
                coset = [];
                power = root;
                while ~any(coset == power)
                    coset(end + 1) = power; %#ok<AGROW>
                    power = mod(2 * power, n);
                end
                if seen(coset(1) + 1)
                    continue
                end
                seen(coset + 1) = true;
                poly = uint32(1);
                for power = coset
                    nextPoly = zeros(numel(poly) + 1, 1, 'uint32');
                    for j = 1:numel(poly)
                        nextPoly(j + 1) = bitxor(nextPoly(j + 1), poly(j));
                        if poly(j) ~= 0
                            logValue = double(logTable(double(poly(j)) + 1));
                            fieldValue = expTable(mod(logValue + power, n) + 1);
                            nextPoly(j) = bitxor(nextPoly(j), fieldValue);
                        end
                    end
                    poly = nextPoly;
                end
                if any(poly > 1)
                    error('Не удалось построить порождающий полином BCH.');
                end
                generator = uint8(mod(conv(double(generator), double(poly)), 2));
            end
            if numel(generator) ~= 161
                error('Степень порождающего полинома BCH должна быть равна 160.');
            end
        end

        function positions = makeLDPCPositions(~)
            % Адреса таблицы B.9 DVB-S2: normal FECFRAME, скорость 5/6.
            positions = [ ...
            0 4362 416 8909 4156 3216 3112 2560 2912 6405 8593 4969 6723 1 2479 ...
            1786 8978 3011 4339 9313 6397 2957 7288 5484 6031 10217 2 10175 9009 9889 ...
            3091 4985 7267 4092 8874 5671 2777 2189 8716 3 9052 4795 3924 3370 10058 ...
            1128 9996 10165 9360 4297 434 5138 4 2379 7834 4835 2327 9843 804 329 ...
            8353 7167 3070 1528 7311 5 3435 7871 348 3693 1876 6585 10340 7144 5870 ...
            2084 4052 2780 6 3917 3111 3476 1304 10331 5939 5199 1611 1991 699 8316 ...
            9960 7 6883 3237 1717 10752 7891 9764 4745 3888 10009 4176 4614 1567 8 ...
            10587 2195 1689 2968 5420 2580 2883 6496 111 6023 1024 4449 9 3786 8593 ...
            2074 3321 5057 1450 3840 5444 6572 3094 9892 1512 10 8548 1848 10372 4585 ...
            7313 6536 6379 1766 9462 2456 5606 9975 11 8204 10593 7935 3636 3882 394 ...
            5968 8561 2395 7289 9267 9978 12 7795 74 1633 9542 6867 7352 6417 7568 ...
            10623 725 2531 9115 13 7151 2482 4260 5003 10105 7419 9203 6691 8798 2092 ...
            8263 3755 14 3600 570 4527 200 9718 6771 1995 8902 5446 768 1103 6520 ...
            15 6304 7621 16 6498 9209 17 7293 6786 18 5950 1708 19 8521 1793 ...
            20 6174 7854 21 9773 1190 22 9517 10268 23 2181 9349 24 1949 5560 ...
            25 1556 555 26 8600 3827 27 5072 1057 28 7928 3542 29 3226 3762 ...
            0 7045 2420 1 9645 2641 2 2774 2452 3 5331 2031 4 9400 7503 ...
            5 1850 2338 6 10456 9774 7 1692 9276 8 10037 4038 9 3964 338 ...
            10 2640 5087 11 858 3473 12 5582 5683 13 9523 916 14 4107 1559 ...
            15 4506 3491 16 8191 4182 17 10192 6157 18 5668 3305 19 3449 1540 ...
            20 4766 2697 21 4069 6675 22 1117 1016 23 5619 3085 24 8483 8400 ...
            25 8255 394 26 6338 5042 27 6174 5119 28 7203 1989 29 1781 5174 ...
            0 1464 3559 1 3376 4214 2 7238 67 3 10595 8831 4 1221 6513 ...
            5 5300 4652 6 1429 9749 7 7878 5131 8 4435 10284 9 6331 5507 ...
            10 6662 4941 11 9614 10238 12 8400 8025 13 9156 5630 14 7067 8878 ...
            15 9027 3415 16 1690 3866 17 2854 8469 18 6206 630 19 363 5453 ...
            20 4125 7008 21 1612 6702 22 9069 9226 23 5767 4060 24 3743 9237 ...
            25 7018 5572 26 8892 4536 27 853 6064 28 8069 5893 29 2051 2885 ...
            0 10691 3153 1 3602 4055 2 328 1717 3 2219 9299 4 1939 7898 ...
            5 617 206 6 8544 1374 7 10676 3240 8 6672 9489 9 3170 7457 ...
            10 7868 5731 11 6121 10732 12 4843 9132 13 580 9591 14 6267 9290 ...
            15 3009 2268 16 195 2419 17 8016 1557 18 1516 9195 19 8062 9064 ...
            20 2095 8968 21 753 7326 22 6291 3833 23 2614 7844 24 2303 646 ...
            25 2075 611 26 4687 362 27 8684 9940 28 4830 2065 29 7038 1363 ...
            0 1769 7837 1 3801 1689 2 10070 2359 3 3667 9918 4 1914 6920 ...
            5 4244 5669 6 10245 7821 7 7648 3944 8 3310 5488 9 6346 9666 ...
            10 7088 6122 11 1291 7827 12 10592 8945 13 3609 7120 14 9168 9112 ...
            15 6203 8052 16 3330 2895 17 4264 10563 18 10556 6496 19 8807 7645 ...
            20 1999 4530 21 9202 6818 22 3403 1734 23 2106 9023 24 6881 3883 ...
            25 3895 2171 26 4062 6424 27 3755 9536 28 4683 2131 29 7347 8027 ...
            ];
            if numel(positions) ~= 600
                error('Таблица B.9 LDPC должна содержать 600 адресов.');
            end
        end

        function codeword = bchEncode(obj, message)
            message = uint8(message(:));
            if numel(message) ~= 53840
                error('Для BCH требуется 53840 информационных битов.');
            end
            work = [message; zeros(160, 1, 'uint8')];
            generator = flipud(obj.BCHGenerator(:));
            for k = 1:numel(message)
                if work(k) ~= 0
                    work(k:k + 160) = bitxor(work(k:k + 160), generator);
                end
            end
            codeword = [message; work(end - 159:end)];
        end

        function codeword = ldpcEncode(obj, info)
            info = uint8(info(:));
            if numel(info) ~= 54000
                error('Для LDPC 5/6 требуется 54000 входных битов.');
            end
            parity = zeros(10800, 1, 'uint8');
            pointer = 1;
            for group = 1:150
                if group <= 15, degree = 13; else, degree = 3; end
                base = obj.LDPCPositions(pointer:pointer + degree - 1);
                pointer = pointer + degree;
                groupBits = info((group - 1) * 360 + (1:360));
                for offset = 0:359
                    if groupBits(offset + 1) ~= 0
                        address = mod(base + 30 * offset, 10800) + 1;
                        parity(address) = bitxor(parity(address), uint8(1));
                    end
                end
            end
            for k = 2:10800
                parity(k) = bitxor(parity(k), parity(k - 1));
            end
            codeword = [info; parity];
        end

        function [info, ok] = ldpcDecodeNoNoise(obj, codeword)
            codeword = uint8(codeword(:));
            if numel(codeword) ~= 64800
                error('Длина LDPC-кадра должна быть 64800 битов.');
            end
            info = codeword(1:54000);
            ok = isequal(obj.ldpcEncode(info), codeword);
        end

        function [message, ok] = bchDecodeNoNoise(obj, codeword)
            codeword = uint8(codeword(:));
            if numel(codeword) ~= 54000
                error('Длина BCH-кадра должна быть 54000 битов.');
            end
            message = codeword(1:53840);
            ok = isequal(obj.bchEncode(message), codeword);
        end

        function sequence = makeBBScrambler(~, count)
            % PRBS: полином 1 + x^14 + x^15, начальное состояние из DVB-S2.
            reg = uint8([1; 0; 0; 1; 0; 1; 0; 1; 0; 0; 0; 0; 0; 0; 0]);
            sequence = zeros(count, 1, 'uint8');
            for k = 1:count
                sequence(k) = bitxor(reg(14), reg(15));
                reg = [sequence(k); reg(1:14)];
            end
        end

        function crc = crc8(~, data)
            % CRC-8 DVB, полином 0xD5.
            crc = uint8(0);
            for b = uint8(data(:)).'
                crc = bitxor(crc, b);
                for k = 1:8
                    if bitget(crc, 8)
                        crc = bitxor(bitshift(crc, 1), uint8(213));
                    else
                        crc = bitshift(crc, 1);
                    end
                end
            end
        end

        function bits = bytesToBits(~, bytes)
            bytes = uint8(bytes(:));
            bits = zeros(8 * numel(bytes), 1, 'uint8');
            for k = 1:8
                bits(k:8:end) = uint8(bitget(bytes, 9 - k));
            end
        end

        function bytes = bitsToBytes(~, bits)
            bits = uint8(bits(:));
            if mod(numel(bits), 8) ~= 0
                error('Количество битов не кратно восьми.');
            end
            weights = uint16([128; 64; 32; 16; 8; 4; 2; 1]);
            bytes = uint8(sum(double(reshape(bits, 8, [])) .* double(weights), 1)).';
        end
    end
end
