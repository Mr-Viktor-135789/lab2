classdef ClassMapper < handle
    % Модулятор и демодулятор DVB-S2 32APSK без дополнительных библиотек.
    properties (SetAccess = private)
        isTransparent;
        Type;
        ModulationOrder;
        PhaseOffset;
        SymbolMapping;
        DecisionMethod;
        LogLanguage;
        Constellation;
        Bits;
        log2M;
    end
    methods
        function obj = ClassMapper(Params, LogLanguage)
            Mapper = Params.Mapper;
            obj.isTransparent = Mapper.isTransparent;
            obj.Type = Mapper.Type;
            obj.ModulationOrder = Mapper.ModulationOrder;
            obj.PhaseOffset = Mapper.PhaseOffset;
            obj.SymbolMapping = Mapper.SymbolMapping;
            obj.DecisionMethod = Mapper.DecisionMethod;
            obj.LogLanguage = LogLanguage;
            obj.log2M = log2(obj.ModulationOrder);
            if obj.ModulationOrder ~= 32 || ...
                    ~isfield(Mapper, 'ModulationType') || ~strcmp(Mapper.ModulationType, '32APSK')
                error('Для этой версии модели требуется модуляция DVB-S2 32APSK.');
            end
            obj.Constellation = obj.makeConstellation();
            obj.Bits = zeros(5, 32, 'uint8');
            for k = 0:31
                for bit = 1:5
                    obj.Bits(bit, k + 1) = uint8(bitget(uint32(k), 6 - bit));
                end
            end
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            bits = uint8(InData(:));
            if mod(numel(bits), 5) ~= 0
                error('Количество битов для 32APSK должно делиться на пять.');
            end
            groups = reshape(bits, 5, []).';
            values = double(groups) * [16; 8; 4; 2; 1];
            OutData = obj.Constellation(values + 1);
        end

        function OutData = StepRx(obj, InData, varargin) %#ok<INUSD>
            if obj.isTransparent
                OutData = InData;
                return
            end
            symbols = InData(:);
            distances = abs(symbols - obj.Constellation.').^2;
            [~, indexes] = min(distances, [], 2);
            values = uint32(indexes - 1);
            OutData = zeros(5 * numel(values), 1, 'uint8');
            for k = 1:5
                OutData(k:5:end) = uint8(bitget(values, 6 - k));
            end
        end
    end

    methods (Access = private)
        function points = makeConstellation(~)
            % Радиусы и углы трёх колец из таблиц DVB-S2 для скорости 5/6.
            ring = [2 * ones(1, 8), 3 * ones(1, 8), ...
                2 1 2 1 2 1 2 1, 3 * ones(1, 8)];
            angles = deg2rad([45 75 -45 -75 135 105 -135 -105, ...
                22.5 67.5 -45 -90 135 90 -157.5 -112.5, ...
                15 45 -15 -45 165 135 -165 -135, ...
                0 45 -22.5 -67.5 157.5 112.5 180 -135]);
            gamma2 = 2.64;
            gamma3 = 4.64;
            r1 = sqrt(32 / (4 + 12 * gamma2^2 + 16 * gamma3^2));
            radii = zeros(1, 32);
            radii(ring == 1) = r1;
            radii(ring == 2) = gamma2 * r1;
            radii(ring == 3) = gamma3 * r1;
            points = (radii .* exp(1i * angles)).';
        end
    end
end
