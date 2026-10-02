classdef ClassMapper < handle
    properties (SetAccess = private) % Переменные из параметров
        % Нужно ли выполнять модуляцию и демодуляцию
            isTransparent;
        % Тип сигнального созвездия
            Type;
        % Размер сигнального созвездия
            ModulationOrder;
        % Ротация сигнального созвездия
            PhaseOffset;
        % Тип отображения бит на точки сигнального созвездия: Binary | Gray
            SymbolMapping;
        % Вариант принятия решений о модуляционных символах: Hard decision
        % | Log-likelihood ratio | Approximate log-likelihood ratio
            DecisionMethod;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Вычисляемые переменные
        % Массив точек сигнального созвездия и соответствующий ему массив
        % бит
            Constellation;
            Bits;
        % Часто используемое значение
            log2M;
        % Объекты для модуляции/демодуляции
            Mapper;
            DeMapper;
    end
    methods
        function obj = ClassMapper(Params, LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Mapper  = Params.Mapper;
            % Инициализация значений переменных из параметров
                obj.isTransparent = Mapper.isTransparent;
                obj.Type            = Mapper.Type;
                obj.ModulationOrder = Mapper.ModulationOrder;
                obj.PhaseOffset     = Mapper.PhaseOffset;
                obj.SymbolMapping   = Mapper.SymbolMapping;
                obj.DecisionMethod  = Mapper.DecisionMethod;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;

            % Расчёт часто используемого значения
                obj.log2M = log2(Mapper.ModulationOrder);
            
            % Инициализация объектов-модуляторов
                if strcmp(Mapper.Type, 'QAM')
                    obj.Mapper = comm.RectangularQAMModulator( ...
                        'ModulationOrder', Mapper.ModulationOrder, ...
                        'PhaseOffset', Mapper.PhaseOffset, ...
                        'BitInput', true, ...
                        'SymbolMapping', Mapper.SymbolMapping ...
                    );
                    obj.DeMapper = comm.RectangularQAMDemodulator( ...
                        'ModulationOrder', Mapper.ModulationOrder, ...
                        'PhaseOffset', Mapper.PhaseOffset, ...
                        'BitOutput', true, ...
                        'SymbolMapping', Mapper.SymbolMapping, ...
                        'DecisionMethod', Mapper.DecisionMethod ...
                    );
                elseif strcmp(Mapper.Type, 'PSK')
                    obj.Mapper = comm.PSKModulator( ...
                        'ModulationOrder', Mapper.ModulationOrder, ...
                        'PhaseOffset', Mapper.PhaseOffset, ...
                        'BitInput', true, ...
                        'SymbolMapping', Mapper.SymbolMapping ...
                    );
                    obj.DeMapper = comm.PSKDemodulator( ...
                        'ModulationOrder', Mapper.ModulationOrder, ...
                        'PhaseOffset', Mapper.PhaseOffset, ...
                        'BitOutput', true, ...
                        'SymbolMapping', Mapper.SymbolMapping, ...
                        'DecisionMethod', Mapper.DecisionMethod ...
                    );
                end

            % Определим массив возможных бит на входе модулятора и
            % соответствующих модуляционных символов
                if obj.isTransparent
                    obj.Bits = 1;
                    obj.Constellation = 1;
                else
                    obj.Bits = de2bi(0:obj.ModulationOrder-1, ...
                        obj.log2M, 'left-msb').';
                    obj.Constellation = obj.Mapper.step(obj.Bits(:));
                end
        end
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return
            end
            
            OutData = obj.Mapper.step(InData);
        end
        function OutData = StepRx(obj, InData, InstChannelParams)
            if obj.isTransparent
                OutData = InData;
                return
            end
            
            if ~(strcmp(obj.DecisionMethod, 'Hard decision'))
                set(obj.DeMapper, 'Variance', InstChannelParams.Variance);
            end
            OutData = obj.DeMapper.step(InData);
        end
    end
end