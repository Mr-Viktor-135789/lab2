classdef ClassEncoder < handle % Класс FEC-кодирования (BCH + LDPC)
    properties
        Mode = 'BCH+LDPC'; % Режим кодирования
    end

        properties
        BCH_cwLen = 54000; % Длина кодового слова BCH (N_bch)
        BCH_k     = 53840; % Длина информационной части BCH (K_bch)
    end

    properties (SetAccess = private) % Вычисляемые/служебные свойства
        isTransparent; % Прозрачный режим (без кодирования)
        LogLanguage; % Язык лога
        Date; % Дата (зарезервировано)
        LDPCcfg; % Конфигурация LDPC (зарезервировано)

        N = 64800; % Длина кодового слова LDPC (n_ldpc)
        K = 54000; % Длина информационной части LDPC (k_ldpc)
        M; % Число проверочных бит (N - K)
        Q; % Шаг сдвига (M / NB)
        NB = 360; % Размер подблока (для DVB-S2)

        BCH_parityBits; % Проверочные биты BCH (зарезервировано)

        ct1; % Таблица 1 (для LDPC)
        ct2; % Таблица 2 (для LDPC)
        TraceObj; % Объект трассировки
    end

    methods
        function obj = ClassEncoder(Params, LogLanguage) % Конструктор
            Encoder = Params.Encoder; % Извлечение параметров
            obj.isTransparent = Encoder.isTransparent; % Режим прозрачности
            obj.LogLanguage = LogLanguage; % Сохранение языка

            obj.M = obj.N-obj.K; % Вычисление M
            obj.Q = obj.M/obj.NB; % Вычисление Q

            % --- Trace ---
            disp('===== FEC (BCH + LDPC) ====='); % Заголовок трассировки
            if isfield(Params,'Common') && isfield(Params.Common,'Trace') % Проверка
                obj.TraceObj = TraceOfConver(Params.Common.Trace); % Создание объекта
            else % Иначе
                obj.TraceObj = TraceOfConver(0); % По умолчанию
            end
        end
        
       
        function OutData = StepTx(obj, InData) % Прямое кодирование
            if obj.isTransparent % Если прозрачный режим
                OutData = InData; % Вернуть вход
                return; % Выход
            end

            switch upper(obj.Mode) % Выбор режима (в верхнем регистре)
                case 'BCH+LDPC' % Режим BCH + LDPC
                    if isempty(obj.ct1), obj.loadLDPCtables(); end % Загрузка таблиц
                    bchOut = obj.encodeBCH(InData); % Кодирование BCH
                    assert(numel(bchOut) == obj.K, 'BCH+LDPC: длина BCH (%d) != K_LDPC (%d)', ... % Проверка
                        numel(bchOut), obj.K); % Длины

                     % --- Trace ---
                     disp(sprintf('[  6] BCH : %6d -> %6d  (+%d проверочных, K=%d, N=%d, t=10)', ... % Лог BCH
                            numel(InData), numel(bchOut), numel(bchOut)-numel(InData), ... % Размеры
                            obj.BCH_k, obj.BCH_cwLen)); % Параметры

                    OutData = obj.encodeLDPC(bchOut); % Кодирование LDPC

                    disp(sprintf('[  7] LDPC: %6d -> %6d  (+%d проверочных, K=%d, N=%d, Q=%d)', ... % Лог LDPC
                            numel(bchOut), numel(OutData), numel(OutData)-numel(bchOut), ... % Размеры
                            obj.K, obj.N, obj.Q)); % Параметры
                    disp(sprintf('       Итог FEC: %d -> %d бит (rate = %.4f, скорость %.4f)', ... % Итог
                        numel(InData), numel(OutData), numel(InData)/numel(OutData), ... % Размеры
                        obj.K/obj.N)); % Скорость
                end % Конец case
            end % Конец switch
        
%% BCH begin
        function OutData = encodeBCH(obj, InData) % Кодирование BCH
            msg = double(InData(:)); % Приведение к double-столбцу
            n_full = 65535; % Полная длина кода BCH
            k_full = n_full - (obj.BCH_cwLen - obj.BCH_k);   % Полная информационная длина (~65375 для R=5/6)
            msg = [msg; zeros(k_full - numel(msg), 1)]; % Дополнение нулями
            code = bchenc(gf(msg.'), n_full, k_full); % Кодирование BCH над GF(2)
            code = double(code.x(:)); % Приведение к double-вектору
            OutData = code(end - obj.BCH_cwLen + 1 : end).';  % Выделение хвоста (54000 бит)
        end
%% BCH end

%% LDPC begin
        function OutData = encodeLDPC(obj, InData) % Кодирование LDPC

            persistent H A B % Кэширование матриц
            if isempty(H) % Если ещё не загружены
                H = dvbs2ldpc(5/6);        % Матрица H (10800 x 64800)
                A = H(:, 1:54000);         % Левая часть (10800 x 54000)
                B = H(:, 54001:end);       % Правая часть (10800 x 10800)
            end
        
            u = mod(double(InData(:)), 2); % Информационные биты (по модулю 2)
            if numel(u) > 54000 % Проверка длины
                error('Входная длина больше K: %d > K=54000', numel(u)); % Ошибка
            end
            u = [u; zeros(54000 - numel(u), 1)]; % Дополнение до K

            acc = mod(A * u, 2);           % Вычисление синдрома (10800 x 1)
            
            p = zeros(10800, 1); % Вектор проверочных бит
            p(1) = acc(1); % Первый бит
            for i = 2:10800 % Цикл по проверочным битам
                p(i) = xor(acc(i), p(i-1)); % Рекуррентное вычисление
            end
        
            OutData = [u; p].'; % Формирование кодового слова
        end
        function loadLDPCtables(obj) % Загрузка таблиц LDPC
            S = load('LDPC_R56_CT.mat'); % Загрузка .mat
            obj.ct1 = S.ct1; % Первая таблица
            obj.ct2 = S.ct2; % Вторая таблица
        end
%% LDPC end

        function OutData = StepRx(obj, InData) % Обратное декодирование
            if obj.isTransparent % Если прозрачный режим
                OutData = InData; % Вернуть вход
                return; % Выход
            end
            OutData = InData; % Заглушка (декодер пока не реализован)
        end
    end
end