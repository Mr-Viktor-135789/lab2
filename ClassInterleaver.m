classdef ClassInterleaver < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять перемежение и деперемежение
            isTransparent;
            TraceObj;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
        C;        % число столбцов = log2M
        R;        % число строк
        log2M;
    end
    methods
        function obj = ClassInterleaver(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Interleaver  = Params.Interleaver;
            % Инициализация значений переменных из параметров
                obj.isTransparent = Interleaver.isTransparent;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;

                if isfield(Params,'Sig') && isfield(Params.Sig,'Modulation')
                    obj.log2M = 5;
                end
                obj.C = obj.log2M;
                if isfield(Params,'Common') && isfield(Params.Common,'Trace')
                    obj.TraceObj = TraceOfConver(Params.Common.Trace);
                else
                    obj.TraceObj = TraceOfConver(0);
                end
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            
            % Здесь должна быть процедура перемежения
            row=ceil(length(InData)/5);
            arr=reshape(InData, 5 ,row).';
            OutData = arr(:).'; 
            
        end
        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            
            % Здесь должна быть процедура деперемежения
            OutData = InData;
        end
    end
end