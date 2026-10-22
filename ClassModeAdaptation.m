classdef ClassModeAdaptation < handle
    properties (SetAccess = private)
        % Параметры из структуры Params
        numPackets;
        UPL;
        DFL;
        K_BCH;
        MATYPE1;
        MATYPE2;
        SYNC;
        SYNCD;
        % Язык вывода
        LogLanguage;
        TraceObj;
    end
    properties (SetAccess = private)
        % Промежуточные результаты
        bbHeader;
        dataField;
        crcValues;
    end
    methods
        function obj = ClassModeAdaptation(Params, LogLanguage)
            if isfield(Params, 'ModeAdaptation')
                MA = Params.ModeAdaptation;
            else
                MA = struct();
            end
        
            % Значения по умолчанию (для команды 8: 32APSK, R=5/6)
            if ~isfield(MA, 'UPL'),     MA.UPL     = 1504;   end
            if ~isfield(MA, 'DFL'),     MA.DFL     = 52640;  end
            if ~isfield(MA, 'K_BCH'),   MA.K_BCH   = 53840;  end
            if ~isfield(MA, 'MATYPE1'), MA.MATYPE1 = 0xF2;   end
            if ~isfield(MA, 'MATYPE2'), MA.MATYPE2 = 0x00;   end
            if ~isfield(MA, 'SYNC'),    MA.SYNC    = 0x47;   end
            if ~isfield(MA, 'SYNCD'),   MA.SYNCD   = 0x0000; end
        
            obj.UPL      = MA.UPL;
            obj.DFL      = MA.DFL;
            obj.K_BCH    = MA.K_BCH;
            obj.MATYPE1  = MA.MATYPE1;
            obj.MATYPE2  = MA.MATYPE2;
            obj.SYNC     = MA.SYNC;
            obj.SYNCD    = MA.SYNCD;
            obj.LogLanguage = LogLanguage;
            obj.TraceObj = TraceOfConver(Params.Common.Trace);

            obj.numPackets = obj.DFL / obj.UPL;
            if mod(obj.numPackets, 1) ~= 0
                error('DFL must be a multiple of UPL');
            end
        
            % --- Trace ---
            disp(' MODE ADAPTATION');
            disp(sprintf('   UPL=%d  DFL=%d  K_BCH=%d  N_pkt=%d  padding=%d', ...
                    obj.UPL, obj.DFL, obj.K_BCH, obj.numPackets, ...
                    obj.K_BCH - 80 - obj.DFL));
            
        end

        function OutData = StepTx(obj, InData)
            % InData: MPEG-TS пакеты (например, 52640 бит)
            % OutData: [BBHEADER; DATA FIELD] (80 + 52640 = 52720 бит)
            
            expectedLen = obj.numPackets * obj.UPL;
            if length(InData) ~= expectedLen
                error('Input length must be %d bits', expectedLen);
            end

            obj.dataField = zeros(obj.DFL, 1);
            obj.crcValues = zeros(obj.numPackets, 1);

            for pktIdx = 1:obj.numPackets
                offset = (pktIdx - 1) * obj.UPL;
                up = InData(offset + 1 : offset + obj.UPL);

                % Проверка синхробайта
                if ~isequal(up(1:8), obj.byteToBits(obj.SYNC))
                    warning('Packet %d does not start with 0x47', pktIdx);
                end

                usefulPart = up(9:end);
                crc = obj.computeCRC8(usefulPart);
                obj.crcValues(pktIdx) = obj.bitsToByte(crc);

                if obj.TraceObj.Level >= 1 && (pktIdx <= 2 || pktIdx == obj.numPackets)
                    fprintf('    pkt%-2d/%d  sync=0x%02X  CRC=0x%02X\n', ...
                        pktIdx, obj.numPackets, obj.bitsToByte(up(1:8)), obj.bitsToByte(crc));
                end
                % --- Trace ---
              
            end
            obj.bbHeader = obj.buildBBHeader();
            crcBB = obj.computeCRC8(obj.bbHeader(1:72));
            crcBBval = obj.bitsToByte(crcBB);
            disp(sprintf('[  4] BBHEADER (80 бит): MATYPE1=0x%02X MATYPE2=0x%02X UPL=0x%04X DFL=0x%04X SYNC=0x%02X SYNCD=0x%04X CRC=0x%02X', ...
                        obj.MATYPE1, obj.MATYPE2, obj.UPL, obj.DFL, obj.SYNC, obj.SYNCD, crcBBval));
            
            if obj.TraceObj.Level >= 2
                obj.TraceObj.checkTrace('длина BBHEADER = 80', numel(obj.bbHeader)==80);
                obj.TraceObj.checkTrace(sprintf('DFL / UPL = %d', obj.DFL/obj.UPL), ...
                    mod(obj.DFL,obj.UPL)==0);
                obj.TraceObj.checkTrace(sprintf('padding = %d', obj.K_BCH-80-obj.DFL), ...
                    obj.K_BCH-80-obj.DFL>=0);
            end



            % Возвращаем один вектор для совместимости с LoopFun
            OutData = [obj.bbHeader; obj.dataField];
        end

        function OutData = StepRx(obj, InData)
            % InData: [BBHEADER; DATA FIELD] (52720 бит)
            % OutData: Восстановленные MPEG-TS пакеты
            
            if length(InData) ~= (80 + obj.DFL)
                error('Input length must be %d bits', 80 + obj.DFL);
            end
            
            dataField = InData(81:end);
            OutData = zeros(obj.numPackets * obj.UPL, 1);
            
            for pktIdx = 1:obj.numPackets
                offset = (pktIdx - 1) * obj.UPL;
                usefulPart = dataField(offset + 9 : offset + obj.UPL);
                
                % Восстанавливаем синхробайт
                OutData(offset + 1 : offset + 8) = obj.byteToBits(obj.SYNC);
                OutData(offset + 9 : offset + obj.UPL) = usefulPart;
            end
        end

        function results = getIntermediateResults(obj)
            results.bbHeader   = obj.bbHeader;
            results.dataField  = obj.dataField;
            results.crcValues  = obj.crcValues;
        end

        % --- Вспомогательные функции ---
        function crc = computeCRC8(obj, bits)
            r = zeros(1, 8);
            for k = 1:length(bits)
                f = xor(bits(k), r(8));
                r_new = zeros(1, 8);
                r_new(1) = f;
                r_new(2) = r(1);
                r_new(3) = xor(r(2), f);
                r_new(4) = r(3);
                r_new(5) = xor(r(4), f);
                r_new(6) = r(5);
                r_new(7) = xor(r(6), f);
                r_new(8) = xor(r(7), f);
                r = r_new;
            end
            crc = r';
        end

        function bbHeader = buildBBHeader(obj)
            bbHeader = zeros(80, 1);
            bbHeader(1:8)   = obj.byteToBits(obj.MATYPE1);
            bbHeader(9:16)  = obj.byteToBits(obj.MATYPE2);
            bbHeader(17:32) = obj.uint16ToBits(obj.UPL);
            bbHeader(33:48) = obj.uint16ToBits(obj.DFL);
            bbHeader(49:56) = obj.byteToBits(obj.SYNC);
            bbHeader(57:72) = obj.uint16ToBits(obj.SYNCD);
            bbHeader(73:80) = obj.computeCRC8(bbHeader(1:72));
        end

        function bits = byteToBits(~, byte)
            bits = zeros(8, 1);
            for i = 1:8
                bits(i) = bitand(bitshift(byte, -(8 - i)), 1);
            end
        end

        function bits = uint16ToBits(~, val)
            bits = zeros(16, 1);
            for i = 1:16
                bits(i) = bitand(bitshift(val, -(16 - i)), 1);
            end
        end

        function byte = bitsToByte(~, bits)
            byte = 0;
            for i = 1:8
                byte = byte + bits(i) * 2^(8 - i);
            end
        end
    end
end
