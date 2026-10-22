classdef ClassModeAdaptation < handle % Класс адаптации режима DVB-S2
    properties (SetAccess = private) % Закрытые свойства
        % Параметры из структуры Params
        numPackets; % Количество пакетов
        UPL; % Длина пользовательского пакета
        DFL; % Длина поля данных
        K_BCH; % Длина BBFRAME (K_bch)
        MATYPE1; % Первый байт MATYPE
        MATYPE2; % Второй байт MATYPE
        SYNC; % Синхробайт (0x47)
        SYNCD; % Синхробайт-дистанция
        % Язык вывода
        LogLanguage; % Язык логов
        TraceObj; % Объект трассировки
    end
    properties (SetAccess = private) % Закрытые свойства (промежуточные)
        % Промежуточные результаты
        bbHeader; % Заголовок BBHEADER (80 бит)
        dataField; % Поле данных (DFL бит)
        crcValues; % Массив CRC для пакетов
    end
    methods
        function obj = ClassModeAdaptation(Params, LogLanguage) % Конструктор
            if isfield(Params, 'ModeAdaptation') % Если параметры заданы
                MA = Params.ModeAdaptation; % Извлечь ModeAdaptation
            else % Иначе
                MA = struct(); % Пустая структура
            end
        
            % Значения по умолчанию (для команды 8: 32APSK, R=5/6)
            if ~isfield(MA, 'UPL'),     MA.UPL     = 1504;   end % UPL по умолчанию
            if ~isfield(MA, 'DFL'),     MA.DFL     = 52640;  end % DFL по умолчанию
            if ~isfield(MA, 'K_BCH'),   MA.K_BCH   = 53840;  end % K_BCH по умолчанию
            if ~isfield(MA, 'MATYPE1'), MA.MATYPE1 = 0xF2;   end % MATYPE1: TS/SIS/CCM/RO=10
            if ~isfield(MA, 'MATYPE2'), MA.MATYPE2 = 0x00;   end % MATYPE2: резерв
            if ~isfield(MA, 'SYNC'),    MA.SYNC    = 0x47;   end % SYNC: 0x47
            if ~isfield(MA, 'SYNCD'),   MA.SYNCD   = 0x0000; end % SYNCD: 0
        
            obj.UPL      = MA.UPL; % Присвоить UPL
            obj.DFL      = MA.DFL; % Присвоить DFL
            obj.K_BCH    = MA.K_BCH; % Присвоить K_BCH
            obj.MATYPE1  = MA.MATYPE1; % Присвоить MATYPE1
            obj.MATYPE2  = MA.MATYPE2; % Присвоить MATYPE2
            obj.SYNC     = MA.SYNC; % Присвоить SYNC
            obj.SYNCD    = MA.SYNCD; % Присвоить SYNCD
            obj.LogLanguage = LogLanguage; % Сохранить язык
            obj.TraceObj = TraceOfConver(Params.Common.Trace); % Создать трассировщик

            obj.numPackets = obj.DFL / obj.UPL; % Вычислить кол-во пакетов
            if mod(obj.numPackets, 1) ~= 0 % Если DFL не кратен UPL
                error('DFL must be a multiple of UPL'); % Ошибка
            end
        
            % --- Trace ---
            disp(' MODE ADAPTATION'); % Заголовок трассировки
            disp(sprintf('   UPL=%d  DFL=%d  K_BCH=%d  N_pkt=%d  padding=%d', ... % Формат вывода
                    obj.UPL, obj.DFL, obj.K_BCH, obj.numPackets, ... % Значения
                    obj.K_BCH - 80 - obj.DFL)); % Размер паддинга
            
        end

        function OutData = StepTx(obj, InData) % Передатчик: адаптация
            % InData: MPEG-TS пакеты (например, 52640 бит)
            % OutData: [BBHEADER; DATA FIELD] (80 + 52640 = 52720 бит)
            
            expectedLen = obj.numPackets * obj.UPL; % Ожидаемая длина
            if length(InData) ~= expectedLen % Если не совпадает
                error('Input length must be %d bits', expectedLen); % Ошибка
            end

            obj.dataField = zeros(obj.DFL, 1); % Инициализация DATA FIELD
            obj.crcValues = zeros(obj.numPackets, 1); % Инициализация массива CRC

            for pktIdx = 1:obj.numPackets % Цикл по пакетам
                offset = (pktIdx - 1) * obj.UPL; % Смещение пакета
                up = InData(offset + 1 : offset + obj.UPL); % Извлечь пакет

                % Проверка синхробайта
                if ~isequal(up(1:8), obj.byteToBits(obj.SYNC)) % Если не 0x47
                    warning('Packet %d does not start with 0x47', pktIdx); % Предупреждение
                end

                usefulPart = up(9:end); % Полезная часть без sync
                crc = obj.computeCRC8(usefulPart); % Вычислить CRC-8
                obj.crcValues(pktIdx) = obj.bitsToByte(crc); % Сохранить CRC

                if obj.TraceObj.Level >= 1 && (pktIdx <= 2 || pktIdx == obj.numPackets) % Условие трассировки
                    fprintf('    pkt%-2d/%d  sync=0x%02X  CRC=0x%02X\n', ... % Формат
                        pktIdx, obj.numPackets, obj.bitsToByte(up(1:8)), obj.bitsToByte(crc)); % Данные
                end
                % --- Trace ---
              
            end
            obj.bbHeader = obj.buildBBHeader(); % Построить BBHEADER
            crcBB = obj.computeCRC8(obj.bbHeader(1:72)); % CRC для BBHEADER
            crcBBval = obj.bitsToByte(crcBB); % Преобразовать в байт
            disp(sprintf('[  4] BBHEADER (80 бит): MATYPE1=0x%02X MATYPE2=0x%02X UPL=0x%04X DFL=0x%04X SYNC=0x%02X SYNCD=0x%04X CRC=0x%02X', ... % Формат вывода
                        obj.MATYPE1, obj.MATYPE2, obj.UPL, obj.DFL, obj.SYNC, obj.SYNCD, crcBBval)); % Значения
            
            if obj.TraceObj.Level >= 2 % Если глубокий уровень трассировки
                obj.TraceObj.checkTrace('длина BBHEADER = 80', numel(obj.bbHeader)==80); % Проверка длины
                obj.TraceObj.checkTrace(sprintf('DFL / UPL = %d', obj.DFL/obj.UPL), ... % Формат проверки
                    mod(obj.DFL,obj.UPL)==0); % Проверка кратности
                obj.TraceObj.checkTrace(sprintf('padding = %d', obj.K_BCH-80-obj.DFL), ... % Формат проверки
                    obj.K_BCH-80-obj.DFL>=0); % Проверка паддинга
            end



            % Возвращаем один вектор для совместимости с LoopFun
            OutData = [obj.bbHeader; obj.dataField]; % Объединение BBHEADER и DATA FIELD
        end

        function OutData = StepRx(obj, InData) % Приемник: восстановление
            % InData: [BBHEADER; DATA FIELD] (52720 бит)
            % OutData: Восстановленные MPEG-TS пакеты
            
            if length(InData) ~= (80 + obj.DFL) % Проверка длины
                error('Input length must be %d bits', 80 + obj.DFL); % Ошибка
            end
            
            dataField = InData(81:end); % Извлечь DATA FIELD
            OutData = zeros(obj.numPackets * obj.UPL, 1); % Инициализация выхода
            
            for pktIdx = 1:obj.numPackets % Цикл по пакетам
                offset = (pktIdx - 1) * obj.UPL; % Смещение пакета
                usefulPart = dataField(offset + 9 : offset + obj.UPL); % Полезная часть
                
                % Восстанавливаем синхробайт
                OutData(offset + 1 : offset + 8) = obj.byteToBits(obj.SYNC); % Вставить 0x47
                OutData(offset + 9 : offset + obj.UPL) = usefulPart; % Вставить данные
            end
        end

        function results = getIntermediateResults(obj) % Получить промежуточные результаты
            results.bbHeader   = obj.bbHeader; % BBHEADER
            results.dataField  = obj.dataField; % DATA FIELD
            results.crcValues  = obj.crcValues; % CRC-значения
        end

        % --- Вспомогательные функции ---
        function crc = computeCRC8(obj, bits) % Вычисление CRC-8
            r = zeros(1, 8); % Инициализация регистров
            for k = 1:length(bits) % Цикл по битам
                f = xor(bits(k), r(8)); % Обратная связь
                r_new = zeros(1, 8); % Новые регистры
                r_new(1) = f; % Регистр 1
                r_new(2) = r(1); % Регистр 2
                r_new(3) = xor(r(2), f); % Регистр 3
                r_new(4) = r(3); % Регистр 4
                r_new(5) = xor(r(4), f); % Регистр 5
                r_new(6) = r(5); % Регистр 6
                r_new(7) = xor(r(6), f); % Регистр 7
                r_new(8) = xor(r(7), f); % Регистр 8
                r = r_new; % Обновить регистры
            end
            crc = r'; % Выходной CRC (столбец)
        end

        function bbHeader = buildBBHeader(obj) % Построение BBHEADER
            bbHeader = zeros(80, 1); % Инициализация
            bbHeader(1:8)   = obj.byteToBits(obj.MATYPE1); % MATYPE-1
            bbHeader(9:16)  = obj.byteToBits(obj.MATYPE2); % MATYPE-2
            bbHeader(17:32) = obj.uint16ToBits(obj.UPL); % UPL (16 бит)
            bbHeader(33:48) = obj.uint16ToBits(obj.DFL); % DFL (16 бит)
            bbHeader(49:56) = obj.byteToBits(obj.SYNC); % SYNC (8 бит)
            bbHeader(57:72) = obj.uint16ToBits(obj.SYNCD); % SYNCD (16 бит)
            bbHeader(73:80) = obj.computeCRC8(bbHeader(1:72)); % CRC-8 (8 бит)
        end

        function bits = byteToBits(~, byte) % Байт в биты
            bits = zeros(8, 1); % Инициализация
            for i = 1:8 % Цикл по битам
                bits(i) = bitand(bitshift(byte, -(8 - i)), 1); % Извлечь бит
            end
        end

        function bits = uint16ToBits(~, val) % 16-бит в биты
            bits = zeros(16, 1); % Инициализация
            for i = 1:16 % Цикл по битам
                bits(i) = bitand(bitshift(val, -(16 - i)), 1); % Извлечь бит
            end
        end

        function byte = bitsToByte(~, bits) % Биты в байт
            byte = 0; % Инициализация
            for i = 1:8 % Цикл по битам
                byte = byte + bits(i) * 2^(8 - i); % Накопление значения
            end
        end
    end
end
