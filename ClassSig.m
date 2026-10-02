classdef ClassSig < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять формирование сигнала и выполнять его обработку
        % при приёме
            isTransparent;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
    end
    methods
        function obj = ClassSig(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Sig  = Params.Sig;
            % Инициализация значений переменных из параметров
                obj.isTransparent = Sig.isTransparent;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            
            % Здесь должна быть процедура формирования сигнала
            OutData = InData;
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            
            % Здесь должна быть процедура, обратная поцедуре формирования
            % сигнала
            OutData = InData;
        end
    end
end