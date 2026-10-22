classdef ClassMapper < handle % Класс модулятора/демодулятора
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять модуляцию и демодуляцию
            isTransparent; % Флаг прозрачности
        % Тип сигнального созвездия
            Type; % Тип (QAM | PSK)
        % Размер сигнального созвездия
            ModulationOrder; % Размер M
        % Поворот сигнального созвездия
            PhaseOffset; % Фазовый сдвиг
        % Тип отображения бит на точки сигнального созвездия: Binary | Gray
            SymbolMapping; % Тип маппинга
        % Вариант принятия решений о модуляционных символах: Hard decision
        % | Log-likelihood ratio | Approximate log-likelihood ratio
            DecisionMethod; % Метод решений
        % Переменная управления языком вывода информации для пользователя
            LogLanguage; % Язык лога
    end
    properties (SetAccess = private) % Вычисляемые переменные
        % Массив точек сигнального созвездия и соответствующих им битов
        % слов
            Constellation; % Точки созвездия
            Bits; % Битовые слова
        % Число бит на символ
            log2M; % log2(M)
        % Объекты для модуляции/демодуляции
            Mapper; % Модулятор
            DeMapper; % Демодулятор
    end
    methods
        function obj = ClassMapper(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Mapper  = Params.Mapper; % Извлечение Mapper
            % Инициализация значений переменных из параметров
                obj.isTransparent = Mapper.isTransparent; % Флаг прозрачности
                obj.Type            = Mapper.Type; % Тип созвездия
                obj.ModulationOrder = Mapper.ModulationOrder; % Размер M
                obj.PhaseOffset     = Mapper.PhaseOffset; % Фазовый сдвиг
                obj.SymbolMapping   = Mapper.SymbolMapping; % Маппинг
                obj.DecisionMethod  = Mapper.DecisionMethod; % Метод решений
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage; % Язык лога

            % Число бит на модуляционный символ
                obj.log2M = log2(Mapper.ModulationOrder); % log2(M)
            
            % Инициализация модулятора-демодулятора
                if strcmp(Mapper.Type, 'QAM') % Если QAM
                    obj.Mapper = comm.RectangularQAMModulator( ... % Модулятор QAM
                        'ModulationOrder', Mapper.ModulationOrder, ... % Размер M
                        'PhaseOffset', Mapper.PhaseOffset, ... % Фазовый сдвиг
                        'BitInput', true, ... % Вход - биты
                        'SymbolMapping', Mapper.SymbolMapping ... % Маппинг
                    ); % Конец создания модулятора
                    obj.DeMapper = comm.RectangularQAMDemodulator( ... % Демодулятор QAM
                        'ModulationOrder', Mapper.ModulationOrder, ... % Размер M
                        'PhaseOffset', Mapper.PhaseOffset, ... % Фазовый сдвиг
                        'BitOutput', true, ... % Выход - биты
                        'SymbolMapping', Mapper.SymbolMapping, ... % Маппинг
                        'DecisionMethod', Mapper.DecisionMethod ... % Метод решений
                    ); % Конец создания демодулятора
                elseif strcmp(Mapper.Type, 'PSK') % Если PSK
                    obj.Mapper = comm.PSKModulator( ... % Модулятор PSK
                        'ModulationOrder', Mapper.ModulationOrder, ... % Размер M
                        'PhaseOffset', Mapper.PhaseOffset, ... % Фазовый сдвиг
                        'BitInput', true, ... % Вход - биты
                        'SymbolMapping', Mapper.SymbolMapping ... % Маппинг
                    ); % Конец создания модулятора
                    obj.DeMapper = comm.PSKDemodulator( ... % Демодулятор PSK
                        'ModulationOrder', Mapper.ModulationOrder, ... % Размер M
                        'PhaseOffset', Mapper.PhaseOffset, ... % Фазовый сдвиг
                        'BitOutput', true, ... % Выход - биты
                        'SymbolMapping', Mapper.SymbolMapping, ... % Маппинг
                        'DecisionMethod', Mapper.DecisionMethod ... % Метод решений
                    ); % Конец создания демодулятора
                end % Конец if

            % Формирование массива созвездия для его точек созвездия и
            % соответствующих модуляционных символов
                if obj.isTransparent % Если прозрачно
                    obj.Bits = 1; % Заглушка
                    obj.Constellation = 1; % Заглушка
                else % Иначе
                    obj.Bits = de2bi(0:obj.ModulationOrder-1, ... % Все комбинации бит
                        obj.log2M, 'left-msb').'; % В матрицу
                    obj.Constellation = obj.Mapper.step(obj.Bits(:)); % Точки созвездия
                end % Конец if
        end % Конец конструктора
        function OutData = StepTx(obj, InData) % Передатчик
            if obj.isTransparent % Если прозрачно
                OutData = InData; % Пропустить
                return % Выход
            end
            
            OutData = obj.Mapper.step(InData); % Модуляция
        end % Конец StepTx
        function OutData = StepRx(obj, InData, InstChannelParams) % Приемник
            if obj.isTransparent % Если прозрачно
                OutData = InData; % Пропустить
                return % Выход
            end
            
            if ~(strcmp(obj.DecisionMethod, 'Hard decision')) % Если не жесткое решение
                set(obj.DeMapper, 'Variance', InstChannelParams.Variance); % Установить дисперсию
            end % Конец if
            OutData = obj.DeMapper.step(InData); % Демодуляция
        end % Конец StepRx
    end % Конец methods
end % Конец класса
