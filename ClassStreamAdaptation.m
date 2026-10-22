classdef ClassStreamAdaptation < handle % Класс потоковой адаптации BBFRAME
    properties (SetAccess = private) % Параметры из структуры Params
        K_BCH; % Длина BBFRAME (бит)
        DFL; % Длина DATA FIELD (бит)
        PADDING_BITS; % Длина паддинга (бит)
        LogLanguage; % Язык лога
    end
    properties (SetAccess = private) % Вычисляемые переменные
        bbFrame; % BBFRAME без скремблирования
        scrambledBBFrame; % BBFRAME после скремблирования
        padding; % Вектор паддинга
        TraceObj; % Объект трассировки
    end
    methods
        function obj = ClassStreamAdaptation(Params, LogLanguage) % Конструктор
            % Конструктор совместим с общим стилем фреймворка
            if isfield(Params, 'StreamAdaptation') % Если поле есть
                SA = Params.StreamAdaptation; % Берём его
            else % Иначе
                SA = struct(); % Пустая структура
            end
            % Если DFL не задан явно, берем из ModeAdaptation
            if isfield(Params, 'ModeAdaptation') && isfield(Params.ModeAdaptation, 'DFL') % Если DFL в MA
                DFL_default = Params.ModeAdaptation.DFL; % Берём оттуда
            else % Иначе
                DFL_default = 52640; % Значение по умолчанию
            end
            if ~isfield(SA, 'K_BCH'), SA.K_BCH = 53840;  end % K_BCH по умолчанию
            if ~isfield(SA, 'DFL'),   SA.DFL   = DFL_default; end % DFL по умолчанию
            obj.K_BCH = SA.K_BCH; % Сохраняем K_BCH
            obj.DFL   = SA.DFL; % Сохраняем DFL
            obj.PADDING_BITS = obj.K_BCH - 80 - obj.DFL; % Расчёт паддинга
            disp('===== STREAM ADAPTATION ====='); % Отладочный вывод
            if obj.PADDING_BITS < 0 % Проверка
                error('K_BCH must be >= 80 + DFL'); % Ошибка
            end
            obj.LogLanguage = LogLanguage; % Сохраняем язык лога
            obj.TraceObj = TraceOfConver(Params.Common.Trace); % Создаём трассировщик
        end
        function OutData = StepTx(obj, InData) % Передающая сторона
            % InData: [BBHEADER; DATA FIELD] (52720 бит)
            % OutData: scrambledBBFrame (53840 бит)
            if length(InData) ~= (80 + obj.DFL) % Проверка длины
                error('Input length must be %d bits', 80 + obj.DFL); % Ошибка
            end
            bbHeader = InData(1:80); % Первые 80 бит — BBHEADER
            dataField = InData(81:end); % Остальное — DATA FIELD
            % Формируем BBFRAME
            obj.padding = zeros(obj.PADDING_BITS, 1); % Паддинг нулями
            obj.bbFrame = [bbHeader; dataField; obj.padding]; % Склейка BBFRAME
            disp(sprintf('[  5] BBFRAME: 80 (BBHEADER) + %d (DFL) + %d (PADDING) = %d бит  OK', ... % Печать
                obj.DFL, obj.PADDING_BITS, numel(obj.bbFrame))); % Аргументы
            disp('       BB scrambling: PRBS 1 + X^14 + X^15, init = 100101010000000'); % Инфо
            % Скремблирование
            obj.scrambledBBFrame = obj.bbScrambling(obj.bbFrame); % BB-скремблинг

            % --- Место для PL-скремблирования / трассировки (TraceObj) ---
            % --- сейчас не используется, зарезервировано под расширение ---
            
            OutData = obj.scrambledBBFrame; % Возврат результата
        end
        function OutData = StepRx(obj, InData) % Приёмная сторона
            % InData: scrambledBBFrame (53840 бит)
            % OutData: [BBHEADER; DATA FIELD] (52720 бит)
            if length(InData) ~= obj.K_BCH % Проверка длины
                error('Input length must be %d bits', obj.K_BCH); % Ошибка
            end
            obj.scrambledBBFrame = InData; % Сохраняем вход
            % Дескремблирование (симметрично)
            obj.bbFrame = obj.bbScrambling(InData); % Обратное скремблирование
            % Отбрасываем padding и возвращаем BBHEADER + DATA FIELD
            OutData = obj.bbFrame(1 : 80 + obj.DFL); % Обрезка до входа
        end
        function results = getIntermediateResults(obj) % Доступ к промежуточным данным
            results.bbFrame          = obj.bbFrame; % BBFRAME
            results.scrambledBBFrame = obj.scrambledBBFrame; % Скремблированный
            results.padding          = obj.padding; % Паддинг
        end
        function scrambled = bbScrambling(obj, bbFrame) % BB-скремблер
            % PRBS: 1 + X^14 + X^15
            initSeq = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0]; % Начальная последовательность
            r = initSeq; % Состояние регистра
            scrambled = zeros(size(bbFrame)); % Выходной вектор
            for i = 1:length(bbFrame) % Цикл по битам
                p = xor(r(14), r(15)); % Бит PRBS
                scrambled(i) = xor(bbFrame(i), p); % XOR с входом
                r = [p, r(1:14)]; % Сдвиг регистра
            end
        end
    end
end
