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
        LDPCPositions; % Теперь это матрица [row, col] из dvbs2ldpc
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
        
        function [infoBits, isConverged] = ldpcDecodeMinSum(obj, llrIn, maxIter)
            % Быстрый встроенный LDPC-декодер MATLAB
            persistent H cfg
            if isempty(H)
                H = dvbs2ldpc(5/6);
                cfg = ldpcDecoderConfig(H);
            end
            % Вызов встроенного декодера (быстро, векторизовано)
            [infoBits, isConverged] = ldpcDecode(double(llrIn(:)), cfg, maxIter);
            infoBits = double(infoBits);
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
            % Используем встроенную матрицу H из стандарта DVB-S2.
            try
                H = dvbs2ldpc(5/6, 'indices');
                positions = H; % [row, col]
            catch
                error('Функция dvbs2ldpc не найдена. Установите Communications Toolbox.');
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
            N = 64800; K = 54000; M = 10800;
            parity = zeros(M, 1, 'uint8');
            
            edges = obj.LDPCPositions;
            for e = 1:size(edges, 1)
                r = edges(e, 1);
                c = edges(e, 2);
                if c <= K
                    if info(c) ~= 0
                        parity(r) = bitxor(parity(r), uint8(1));
                    end
                end
            end
            
            for k = 2:M
                parity(k) = bitxor(parity(k), parity(k-1));
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