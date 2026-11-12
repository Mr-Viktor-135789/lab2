classdef ClassInterleaver < handle
    % Перемежитель битов для модуляции DVB-S2 32APSK.
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        ModulationOrder;
    end
    methods
        function obj = ClassInterleaver(Params, LogLanguage)
            obj.isTransparent = Params.Interleaver.isTransparent;
            obj.LogLanguage = LogLanguage;
            obj.ModulationOrder = Params.Mapper.ModulationOrder;
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            if obj.ModulationOrder ~= 32 || numel(InData) ~= 64800
                error('Перемежитель настроен на кадр DVB-S2 32APSK длиной 64800 битов.');
            end
            % Записываем пять потоков по столбцам, считываем по строкам.
            matrix = reshape(uint8(InData(:)), 12960, 5);
            OutData = reshape(matrix.', [], 1);
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            if obj.ModulationOrder ~= 32 || numel(InData) ~= 64800
                error('На вход деперемежителя поступил кадр неверной длины.');
            end
            % Без uint8 — LLR это double, отрицательные значения важны!
            matrix = reshape(InData(:), 5, []);
            OutData = reshape(matrix.', [], 1);
        end
    end
end
