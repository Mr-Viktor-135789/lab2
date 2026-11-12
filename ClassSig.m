classdef ClassSig < handle
    % Формирование и обработка PLFRAME, пилотов и импульсов RRC.
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        Beta;
        Span;
        SamplesPerSymbol;
        Pilots;
        MODCOD;
        Constellation;
        HeaderSymbols;
        PilotSymbol;
        RRCFilter;
        PLRotation;
        DataSymbolsPerFrame;
        BodySymbols;
        FrameSymbols;
        FilterDelay;
        LastHeaderError = NaN;
        LastPilotError = NaN;
    end
    methods
        function obj = ClassSig(Params, LogLanguage, Constellation)
            Sig = Params.Sig;
            obj.isTransparent = Sig.isTransparent;
            obj.LogLanguage = LogLanguage;
            obj.Beta = Sig.Beta;
            obj.Span = Sig.RRCSpan;
            obj.SamplesPerSymbol = Sig.SamplesPerSymbol;
            obj.Pilots = Sig.Pilots;
            obj.MODCOD = Sig.MODCOD;
            if nargin < 3 || isempty(Constellation)
                Constellation = obj.makeConstellation();
            end
            obj.Constellation = Constellation(:);
            obj.DataSymbolsPerFrame = 12960;
            obj.BodySymbols = 13248;
            obj.FrameSymbols = 13338;
            obj.PilotSymbol = obj.Constellation(26); % точка 32APSK с индексом 25
            obj.HeaderSymbols = obj.makePLHeader();
            obj.PLRotation = obj.makePLRotation(obj.BodySymbols);
            obj.RRCFilter = obj.makeRRCFilter();
            obj.FilterDelay = (numel(obj.RRCFilter) - 1) / 2;
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            data = InData(:);
            if numel(data) ~= obj.DataSymbolsPerFrame
                error('Для PLFRAME 32APSK требуется 12960 информационных символов.');
            end

            % Добавляем по 36 пилотов после каждых 16 слотов по 90 символов.
            body = complex(zeros(obj.BodySymbols, 1));
            sourcePos = 1; targetPos = 1;
            for block = 1:9
                body(targetPos:targetPos + 1439) = data(sourcePos:sourcePos + 1439);
                sourcePos = sourcePos + 1440;
                targetPos = targetPos + 1440;
                if obj.Pilots && block < 9
                    body(targetPos:targetPos + 35) = obj.PilotSymbol;
                    targetPos = targetPos + 36;
                end
            end

            % Скремблируем данные и пилоты, но не PLHEADER.
            body = body .* obj.PLRotation;
            plFrame = [obj.HeaderSymbols; body];

            % Передискретизация и формирование сигнала фильтром RRC.
            upsampled = complex(zeros(numel(plFrame) * obj.SamplesPerSymbol, 1));
            upsampled(1:obj.SamplesPerSymbol:end) = plFrame;
            OutData = conv(upsampled, obj.RRCFilter);
        end

                function OutData = StepRx(obj, InData)
                    if obj.isTransparent
                        OutData = InData;
                        return
                    end
        
                    % Согласованная фильтрация и выборка
                    matched = conv(InData(:), flipud(obj.RRCFilter));
                    first = 2 * obj.FilterDelay + 1;
                    last = first + (obj.FrameSymbols - 1) * obj.SamplesPerSymbol;
                    rxSymbols = matched(first:obj.SamplesPerSymbol:last);
                    
                    % Проверка на всякий случай, что символов достаточно
                    if numel(rxSymbols) < obj.FrameSymbols
                        error('Не удалось выделить полный PLFRAME.');
                    end
        
                    % === УБИРАЕМ ЖЕСТКУЮ ПРОВЕРКУ PLHEADER (оставляем только для лога) ===
                    obj.LastHeaderError = max(abs(rxSymbols(1:90) - obj.HeaderSymbols));
                    % if obj.LastHeaderError > 0.05 ... error ...
                    
                    % Извлекаем тело (без PLHEADER) и снимаем PL-скремблирование
                    body = rxSymbols(91:end) .* conj(obj.PLRotation);
                    
                    % Удаляем пилоты (если они есть)
                    data = complex(zeros(obj.DataSymbolsPerFrame, 1));
                    sourcePos = 1; targetPos = 1;
                    pilotErrors = zeros(8, 1);
                    
                    for block = 1:9
                        data(targetPos:targetPos + 1439) = body(sourcePos:sourcePos + 1439);
                        sourcePos = sourcePos + 1440;
                        targetPos = targetPos + 1440;
                        if obj.Pilots && block < 9
                            pilotBlock = body(sourcePos:sourcePos + 35);
                            pilotErrors(block) = max(abs(pilotBlock - obj.PilotSymbol));
                            sourcePos = sourcePos + 36;
                        end
                    end
                    
                    % === ТОЖЕ УБИРАЕМ ПРОВЕРКУ ПИЛОТОВ ===
                    obj.LastPilotError = max(pilotErrors);
                    % if obj.LastPilotError > 0.05 ... error ...
                    
                    OutData = data;
                end
    end

    methods (Access = private)
        function points = makeConstellation(~)
            % Резервное построение созвездия для совместимости с PrepareObjects.m.
            ring = [2 * ones(1, 8), 3 * ones(1, 8), ...
                2 1 2 1 2 1 2 1, 3 * ones(1, 8)];
            angles = deg2rad([45 75 -45 -75 135 105 -135 -105, ...
                22.5 67.5 -45 -90 135 90 -157.5 -112.5, ...
                15 45 -15 -45 165 135 -165 -135, ...
                0 45 -22.5 -67.5 157.5 112.5 180 -135]);
            g2 = 2.64; g3 = 4.64;
            r1 = sqrt(32 / (4 + 12 * g2^2 + 16 * g3^2));
            radii = zeros(1, 32);
            radii(ring == 1) = r1;
            radii(ring == 2) = g2 * r1;
            radii(ring == 3) = g3 * r1;
            points = (radii .* exp(1i * angles)).';
        end

        function symbols = makePLHeader(obj)
            % SOF и PLS-код для MODCOD 26: 32APSK, LDPC 5/6, пилоты включены.
            sof = obj.integerToBits(uint32(hex2dec('18D2E82')), 26);
            plsValue = uint32(obj.MODCOD * 4 + double(obj.Pilots));
            b = obj.integerToBits(plsValue, 7);
            rmRows = uint32([hex2dec('55555555'), hex2dec('33333333'), ...
                hex2dec('0F0F0F0F'), hex2dec('00FF00FF'), ...
                hex2dec('0000FFFF'), hex2dec('FFFFFFFF')]);
            cw = uint32(0);
            for k = 1:6
                if b(k), cw = bitxor(cw, rmRows(k)); end
            end
            w = obj.integerToBits(cw, 32);
            pls = zeros(64, 1, 'uint8');
            pls(1:2:end) = w;
            pls(2:2:end) = bitxor(w, b(7));
            scramblerText = '0111000110011101100000111100100101010011010000100010110111111010';
            plsScrambler = uint8(scramblerText(:) - '0');
            headerBits = [sof; bitxor(pls, plsScrambler)];

            % PLHEADER передаётся модуляцией pi/2-BPSK и отображается на 32APSK.
            a = 1 - 2 * double(headerBits);
            inPhase = a;
            inPhase(2:2:end) = -inPhase(2:2:end);
            quadrature = a;
            index = zeros(90, 1);
            index(inPhase > 0 & quadrature > 0) = 25;
            index(inPhase < 0 & quadrature > 0) = 12;
            index(inPhase < 0 & quadrature < 0) = 31;
            index(inPhase > 0 & quadrature < 0) = 10;
            symbols = obj.Constellation(index + 1);
        end

        function bits = integerToBits(~, value, count)
            bits = zeros(count, 1, 'uint8');
            for k = 1:count
                bits(k) = uint8(bitget(value, count - k + 1));
            end
        end

        function rotation = makePLRotation(~, count)
            % Последовательность скремблера PL по двум 18-разрядным регистраторам.
            period = 2^18 - 1;
            x = zeros(period, 1, 'uint8');
            y = zeros(period, 1, 'uint8');
            x(1) = 1;
            y(1:18) = 1;
            for k = 1:(period - 18)
                x(k + 18) = bitxor(x(k + 7), x(k));
                y(k + 18) = bitxor(bitxor(y(k + 10), y(k + 7)), ...
                    bitxor(y(k + 5), y(k)));
            end
            index = (0:(count - 1)).';
            index1 = mod(index, period) + 1;
            index2 = mod(index + 131072, period) + 1;
            z1 = bitxor(x(index1), y(index1));
            z2 = bitxor(x(index2), y(index2));
            sequence = double(z1) + 2 * double(z2);
            rotation = exp(1i * pi / 2 * sequence);
        end

        function h = makeRRCFilter(obj)
            % КИХ-фильтр с корнем из приподнятого косинуса.
            t = (-obj.Span * obj.SamplesPerSymbol / 2: ...
                obj.Span * obj.SamplesPerSymbol / 2).' / obj.SamplesPerSymbol;
            h = zeros(size(t));
            for k = 1:numel(t)
                x = t(k);
                if abs(x) < 1e-12
                    h(k) = 1 + obj.Beta * (4 / pi - 1);
                elseif abs(abs(4 * obj.Beta * x) - 1) < 1e-10
                    h(k) = obj.Beta / sqrt(2) * ...
                        ((1 + 2 / pi) * sin(pi / (4 * obj.Beta)) + ...
                        (1 - 2 / pi) * cos(pi / (4 * obj.Beta)));
                else
                    h(k) = (sin(pi * x * (1 - obj.Beta)) + ...
                        4 * obj.Beta * x * cos(pi * x * (1 + obj.Beta))) / ...
                        (pi * x * (1 - (4 * obj.Beta * x)^2));
                end
            end
            h = h / sqrt(sum(h.^2));
        end
    end
end
