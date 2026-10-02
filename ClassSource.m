classdef ClassSource < handle
    properties (SetAccess = private) % Переменные из параметров
        % Количество бит в одном кадре
            NumBitsPerFrame;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
    end
    methods
        function obj = ClassSource(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Source  = Params.Source;
            % Инициализация значений переменных из параметров
                obj.NumBitsPerFrame = Source.NumBitsPerFrame;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;
        end
        function Bits = Step(obj)
            Bits = randi(2, obj.NumBitsPerFrame, 1) - 1;
        end
    end
end