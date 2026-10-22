classdef ClassEncoder < handle % Класс кодирования BCH+LDPC
    properties % Открытые свойства
        Mode = 'BCH+LDPC'; % Режим: BCH+LDPC
    end

        properties % Параметры BCH
        BCH_cwLen = 54000; % Длина кодового слова BCH
        BCH_k     = 53840; % Длина информационного слова BCH
    end

    properties (SetAccess = private) % Приватные свойства
        isTransparent; % Флаг прозрачности
        LogLanguage; % Язык лога
        Date; % Дата (резерв)
        LDPCcfg; % Конфиг LDPC (резерв)

        N = 64800; % Длина LDPC-кода
        K = 54000; % Информационных бит LDPC
        M; % Проверочных бит
        Q; % Шаг LDPC
        NB = 360; % Размер группы

        BCH_parityBits; % Четность BCH (резерв)

        ct1; % Таблица 1
        ct2; % Таблица 2
        TraceObj; % Объект трассировки
    end

    methods
        function obj = ClassEncoder(Params, LogLanguage) % Конструктор
            Encoder = Params.Encoder; % Извлечение Encoder
            obj.isTransparent = Encoder.isTransparent; % Флаг прозрачности
            obj.LogLanguage = LogLanguage; % Язык лога

            obj.M = obj.N-obj.K;         % Число проверочных бит
            obj.Q = obj.M/obj.NB;        % Шаг LDPC

            % --- Trace ---
            disp('===== FEC (BCH + LDPC) ====='); % Заголовок трассы
            if isfield(Params,'Common') && isfield(Params.Common,'Trace') % Если трассировка
                obj.TraceObj = TraceOfConver(Params.Common.Trace); % Создать
            else % Иначе
                obj.TraceObj = TraceOfConver(0); % Отключить
            end
        end
        
       
        function OutData = StepTx(obj, InData) % Передатчик
            if obj.isTransparent % Если прозрачно
                OutData = InData; % Пропустить
                return; % Выход
            end

            switch upper(obj.Mode) % Выбор режима
                case 'BCH+LDPC' % BCH+LDPC
                    if isempty(obj.ct1), obj.loadLDPCtables(); end % Загрузка таблиц
                    bchOut = obj.encodeBCH(InData); % Кодирование BCH
                    assert(numel(bchOut) == obj.K, 'BCH+LDPC: длина BCH (%d) != K_LDPC (%d)', ... % Проверка длины
                        numel(bchOut), obj.K); % Данные для проверки

                     % --- Trace ---
                     disp(sprintf('[  6] BCH : %6d -> %6d  (+%d проверочных, K=%d, N=%d, t=10)', ... % Трасса BCH
                            numel(InData), numel(bchOut), numel(bchOut)-numel(InData), ... % Размеры
                            obj.BCH_k, obj.BCH_cwLen)); % Параметры

                    OutData = obj.encodeLDPC(bchOut); % Кодирование LDPC

                    disp(sprintf('[  7] LDPC: %6d -> %6d  (+%d проверочных, K=%d, N=%d, Q=%d)', ... % Трасса LDPC
                            numel(bchOut), numel(OutData), numel(OutData)-numel(bchOut), ... % Размеры
                            obj.K, obj.N, obj.Q)); % Параметры
                    disp(sprintf('       Итог FEC: %d -> %d бит (rate = %.4f, теоретическая %.4f)', ... % Итоговая трасса
                        numel(InData), numel(OutData), numel(InData)/numel(OutData), ... % Размеры
                        obj.K/obj.N)); % Скорость
                end % ВНИМАНИЕ: лишний end? (в исходнике так)
            end % Закрытие switch
        end % Закрытие функции
        
%% BCH begin
        function OutData = encodeBCH(obj, InData) % Кодирование BCH
            msg = double(InData(:)); % Вход в double-вектор
            n_full = 65535; % Полная длина BCH
            k_full = n_full - (obj.BCH_cwLen - obj.BCH_k);   % 65375 для R=5/6
            msg = [msg; zeros(k_full - numel(msg), 1)]; % Дополнение нулями
            code = bchenc(gf(msg.'), n_full, k_full); % BCH-кодирование
            code = double(code.x(:)); % В double-вектор
            OutData = code(end - obj.BCH_cwLen + 1 : end).';  % Усечение до 54000
        end
%% BCH end

%% LDPC begin
        function OutData = encodeLDPC(obj, InData) % Кодирование LDPC

            persistent H A B % Постоянные матрицы
            if isempty(H) % Если ещё не загружены
                H = dvbs2ldpc(5/6);        % 10800 x 64800
                A = H(:, 1:54000);         % 10800 x 54000
                B = H(:, 54001:end);       % 10800 x 10800
            end
        
            u = mod(double(InData(:)), 2); % Информационные биты
            if numel(u) > 54000 % Если больше K
                error('Длина входа больше K: %d > K=54000', numel(u)); % Ошибка
            end
            u = [u; zeros(54000 - numel(u), 1)]; % Дополнение до K

            acc = mod(A * u, 2);           % 10800 x 1, аккумулятор
            
            p = zeros(10800, 1); % Вектор четности
            p(1) = acc(1); % Первый бит
            for i = 2:10800 % Цикл по остальным
                p(i) = xor(acc(i), p(i-1)); % Накопление XOR
            end
        
            OutData = [u; p].'; % Выход: [данные; четность]
        end
        function loadLDPCtables(obj) % Загрузка таблиц LDPC
            S = load('LDPC_R56_CT.mat'); % Загрузка MAT-файла
            obj.ct1 = S.ct1; % Таблица 1
            obj.ct2 = S.ct2; % Таблица 2
        end
%% LDPC end

        function OutData = StepRx(obj, InData) % Приемник
            if obj.isTransparent % Если прозрачно
                OutData = InData; % Пропустить
                return; % Выход
            end
            OutData = InData; % Заглушка (декодер не реализован)
        end
    end
end
