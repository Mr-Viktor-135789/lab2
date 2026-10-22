classdef ClassInterleaver < handle % Класс перемежения/деперемежения
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять перемежение и деперемежение
            isTransparent; % Флаг прозрачности
            TraceObj; % Объект трассировки
        % Переменная управления языком вывода информации для пользователя
            LogLanguage; % Язык лога
    end
    properties (SetAccess = private) % Вычисляемые переменные
        C;        % Число столбцов = log2M
        R;        % Число строк
        log2M;    % Логарифм порядка модуляции
    end
    methods
        function obj = ClassInterleaver(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Interleaver  = Params.Interleaver; % Извлечение Interleaver
            % Инициализация значений переменных из параметров
                obj.isTransparent = Interleaver.isTransparent; % Флаг прозрачности
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage; % Сохранение языка

                if isfield(Params,'Sig') && isfield(Params.Sig,'Modulation') % Если задана модуляция
                    obj.log2M = 5; % Для 32APSK log2M = 5
                end
                obj.C = obj.log2M; % Число столбцов
                if isfield(Params,'Common') && isfield(Params.Common,'Trace') % Если есть трассировка
                    obj.TraceObj = TraceOfConver(Params.Common.Trace); % Создание объекта
                else
                    obj.TraceObj = TraceOfConver(0); % Без трассировки
                end
        end
        function OutData = StepTx(obj, InData) % Перемежение
            if obj.isTransparent % Если прозрачно
                OutData = InData; % Пропуск
                return
            end
            
            % Запись должна быть по столбцам
            row=ceil(length(InData)/5); % Число строк
            arr=reshape(InData, 5 ,row).'; % Запись по столбцам, чтение по строкам
            OutData = arr(:).'; % Выходной вектор
            
        end
        function OutData = StepRx(obj, InData) % Деперемежение
            if obj.isTransparent % Если прозрачно
                OutData = InData; % Пропуск
                return
            end
            
            % Чтение должно быть по строкам
            OutData = InData; % Заглушка (обратное перемежение не реализовано)
        end
    end
end