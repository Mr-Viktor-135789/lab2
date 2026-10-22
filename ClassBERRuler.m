classdef ClassBERRuler < handle % Объявление класса
    properties (SetAccess = private) % Переменные из параметров
    % Инициализация класса BERRuler
        % Из Common
            SaveFileName; % Имя файла сохранения
            SaveDirName; % Имя директории сохранения
            NumOneIterFrames; % Кадров за итерацию
            NumWorkers; % Количество воркеров
            isRealTimeLog; % Флаги логирования
        % Из BER
            h2Precision; % Точность h2
            BERPrecision; % Точность BER
            BERNumRateDigits; % Знаков для бит
            FERNumRateDigits; % Знаков для кадров
            MinNumTrFrames; % Мин. кадров для расчета
            h2dBInit; % Начальное h2
            h2dBInitStep; % Начальный шаг
            h2dBMaxStep; % Макс. шаг
            h2dBMinStep; % Мин. шаг
            h2dBMax; % Макс. h2
            MinBER; % Целевой BER
            MinNumErBits; % Мин. ошибочных бит
            MinFER; % Целевой FER
            MinNumErFrames; % Мин. ошибочных кадров
            MaxNumTrBits % Макс. переданных бит
            MaxNumTrFrames % Макс. переданных кадров
            MaxBERRate; % Макс. отношение BER
            MinBERRate; % Мин. отношение BER
        % Переменная управления языком вывода
            LogLanguage; % Язык лога
    end
    properties (SetAccess = private) % Переменные, вычисляемые классом
        h2dB; % Текущее значение h2
        isStop; % Флаг остановки
        OneWorkerNumOneIterFrames; % Кадров на воркер
    end
    properties (SetAccess = private) % Строковые переменные
        strh2Precision; % Строка точности h2
        strh2NumDigits; % Строка разрядности h2
        strBERPrecision; % Строка точности BER
        strBERNumRateDigits; % Строка разрядности BER
        strFERNumRateDigits; % Строка разрядности FER
    end    
    properties (SetAccess = private) % Переменные, вычисляемые для статистики
        h2dBs; % Массив h2
        NumTrBits; % Массив переданных бит
        NumTrFrames; % Массив переданных кадров
        NumErBits; % Массив ошибочных бит
        NumErFrames; % Массив ошибочных кадров
    end
    properties (SetAccess = private) % Переменные, вычисляемые для расчета
        isMainCalcFinished; % Флаг завершения
        h2dBStep; % Текущий шаг h2
        Addh2dBs; % Дополнительные точки
        Log; % Массив логов
        FullSaveFileName; % Полный путь сохранения
        FullLogFileName; % Полный путь лога
    end
    methods
        function obj = ClassBERRuler(Params, ParamsNum, NumParams, ... % Конструктор
                LogLanguage) % Язык лога
            % Выделим поля Params, необходимые для инициализации
                Common = Params.Common; % Извлечение Common
                BER    = Params.BER; % Извлечение BER
            % Инициализация значений переменных из Common
                obj.SaveFileName     = Common.SaveFileName; % Имя файла
                obj.SaveDirName      = Common.SaveDirName; % Директория
                obj.NumOneIterFrames = Common.NumOneIterFrames; % Кадров за итерацию
                obj.NumWorkers       = Common.NumWorkers; % Количество воркеров
                obj.isRealTimeLog(1) = Common.isRealTimeLogCWin; % Лог в окно
                obj.isRealTimeLog(2) = Common.isRealTimeLogFile; % Лог в файл
            % Инициализация значений переменных из BER
                obj.h2Precision      = BER.h2Precision; % Точность h2
                obj.BERPrecision     = BER.BERPrecision; % Точность BER
                obj.BERNumRateDigits = BER.BERNumRateDigits; % Разрядность BER
                obj.FERNumRateDigits = BER.FERNumRateDigits; % Разрядность FER
                obj.MinNumTrFrames   = BER.MinNumTrFrames; % Мин. кадров
                obj.h2dBInit         = BER.h2dBInit; % Начальное h2
                obj.h2dBInitStep     = BER.h2dBInitStep; % Начальный шаг
                obj.h2dBMaxStep      = BER.h2dBMaxStep; % Макс. шаг
                obj.h2dBMinStep      = BER.h2dBMinStep; % Мин. шаг
                obj.h2dBMax          = BER.h2dBMax; % Макс. h2
                obj.MinBER           = BER.MinBER; % Целевой BER
                obj.MinNumErBits     = BER.MinNumErBits; % Мин. ошибок
                obj.MinFER           = BER.MinFER; % Целевой FER
                obj.MinNumErFrames   = BER.MinNumErFrames; % Мин. кадров с ошибками
                obj.MaxNumTrBits     = BER.MaxNumTrBits; % Макс. бит
                obj.MaxNumTrFrames   = BER.MaxNumTrFrames; % Макс. кадров
                obj.MaxBERRate       = BER.MaxBERRate; % Макс. отношение
                obj.MinBERRate       = BER.MinBERRate; % Мин. отношение
            % Инициализация LogLanguage
                obj.LogLanguage = LogLanguage; % Сохранение языка
            % Инициализация переменных, вычисляемых классом: h2dB и isStop
                obj.h2dB   = obj.h2dBInit; % Установка h2
                obj.isStop = false; % Сброс флага остановки
            % Формирование строковых значений для вывода
                obj.strh2Precision      = sprintf('%d', obj.h2Precision); % Точность h2
                if obj.h2Precision == 0 % Если точность 0
                    obj.strh2NumDigits      = sprintf('%d', ... % Разрядность
                        obj.h2Precision + 2); % 2 знака
                else % Иначе
                    obj.strh2NumDigits      = sprintf('%d', ... % Разрядность
                        obj.h2Precision + 3); % 3 знака
                end
                obj.strBERPrecision     = sprintf('%d', obj.BERPrecision); % Точность BER
                obj.strBERNumRateDigits = sprintf('%d', ... % Разрядность BER
                    obj.BERNumRateDigits); % Перевод в строку
                obj.strFERNumRateDigits = sprintf('%d', ... % Разрядность FER
                    obj.FERNumRateDigits); % Перевод в строку
            % Округление значений h2
                obj.h2dBInit     = obj.Round(obj.h2dBInit); % Округление начального
                obj.h2dBInitStep = obj.Round(obj.h2dBInitStep); % Округление шага
                obj.h2dBMaxStep  = obj.Round(obj.h2dBMaxStep); % Округление макс. шага
                obj.h2dBMinStep  = obj.Round(obj.h2dBMinStep); % Округление мин. шага
                obj.h2dBMax      = obj.Round(obj.h2dBMax); % Округление макс. h2
            % Распределение кадров по воркерам
                obj.OneWorkerNumOneIterFrames = zeros(1, ... % Инициализация массива
                    Common.NumWorkers) + round(Common.NumOneIterFrames ... % Равномерное
                    / Common.NumWorkers); % Распределение
                obj.OneWorkerNumOneIterFrames(end) = ... % Корректировка
                    Common.NumOneIterFrames - ... % Остатка
                    sum(obj.OneWorkerNumOneIterFrames(1:end-1)); % Для последнего воркера
            % Инициализация переменных для статистики
                obj.h2dBs       = obj.h2dB; % Массив h2
                obj.NumTrBits   = 0; % Переданные биты
                obj.NumTrFrames = 0; % Переданные кадры
                obj.NumErBits   = 0; % Ошибочные биты
                obj.NumErFrames = 0; % Ошибочные кадры
            % Инициализация переменных для расчета
                obj.isMainCalcFinished = false; % Флаг завершения
                obj.h2dBStep = obj.h2dBInitStep; % Текущий шаг
                obj.Addh2dBs = []; % Доп. точки пусты
            % Проверка и создание директории
                if ~isfolder(obj.SaveDirName) % Если папки нет
                    mkdir(obj.SaveDirName); % Создать папку
                end
            % Определение разделителя пути
                if isunix % Если Linux
                    PathDelimiter = '/'; % Разделитель '/'
                elseif ispc % Если Windows
                    PathDelimiter = '\'; % Разделитель '\'
                else % Если неизвестно
                    if strcmp(obj.LogLanguage, 'Russian') % Русский
                        error('Не удалось определить платформу!'); % Ошибка
                    else % Английский
                        error('Cannot recognize platform!'); % Ошибка
                    end
                end            
                obj.FullLogFileName = [obj.SaveDirName, PathDelimiter, ... % Полный путь
                    obj.SaveFileName, '.log']; % Лог-файла
                obj.FullSaveFileName = [obj.SaveDirName, PathDelimiter, ... % Полный путь
                    obj.SaveFileName, '.mat']; % Файла данных
            % Вывод начального лога
                if strcmp(obj.LogLanguage, 'Russian') % Если русский
                    LogStr1 = sprintf(['%s Старт вычисления ', ... % Формат
                        'кривой %s (%d из %d).\n'], datestr(now), ... % Подстановка
                        obj.SaveFileName, ParamsNum, NumParams); % Данных
                else % Если английский
                    LogStr1 = sprintf(['%s Start of calculation ', ... % Формат
                        'the curve %s (%d of %d).\n'], ... % Подстановка
                        datestr(now), obj.SaveFileName, ParamsNum, ... % Данных
                        NumParams); % Параметров
                end
                if strcmp(obj.LogLanguage, 'Russian') % Если русский
                    LogStr2 = sprintf(['%s   Старт основных ', ... % Формат
                        'вычислений.\n'], datestr(now)); % Подстановка времени
                else % Если английский
                    LogStr2 = sprintf(['%s   Start of the ', ... % Формат
                        'main calculations.\n'], datestr(now)); % Подстановка времени
                end                        
            % Сохранение лога в массив
                obj.Log = cell(2, 1); % Ячейка для логов
                obj.Log{1} = {LogStr1; LogStr2}; % В окно
                obj.Log{2} = obj.Log{1}; % В файл
                for k = 1:2 % Цикл по логам
                    if k == 1 % Для окна
                        obj.PrintLog(k, obj.isRealTimeLog(k)); % Печать
                    else % Для файла
                        obj.PrintLog(k, 1); % Печать
                    end
                    if obj.isRealTimeLog(k) % Если реалтайм
                        obj.Log{k}{3} = ''; % Очистка строки
                    else % Иначе
                        obj.Log{k} = cell(0); % Очистка лога
                    end
                end
        end
        function isPointFinished = Step(obj, Objs) % Шаг моделирования
            % Обновление статистики
                for k = 1:length(Objs) % Цикл по объектам
                    obj.NumTrBits(end)   = obj.NumTrBits(end)   + ... % Накопление бит
                        Objs{k}.Stat.NumTrBits; % Из статистики
                    obj.NumTrFrames(end) = obj.NumTrFrames(end) + ... % Накопление кадров
                        Objs{k}.Stat.NumTrFrames; % Из статистики
                    obj.NumErBits(end)   = obj.NumErBits(end)   + ... % Накопление ошибок
                        Objs{k}.Stat.NumErBits; % Из статистики
                    obj.NumErFrames(end) = obj.NumErFrames(end) + ... % Накопление кадров с ошибками
                        Objs{k}.Stat.NumErFrames; % Из статистики
                    Objs{k}.Stat.Reset(); % Сброс статистики воркера
                end
            % Проверка превышения сложности
                isComplexityExceeded = false; % Флаг сложности
                if (obj.NumTrBits(end) > obj.MaxNumTrBits) || ... % Если бит больше
                        (obj.NumTrFrames(end) > obj.MaxNumTrFrames) % Или кадров больше
                    isComplexityExceeded = true; % Установить флаг
                end
            % Проверка завершения точки
                isPointFinished = false; % Флаг завершения точки
                if ((obj.NumErBits(end) >= obj.MinNumErBits) && ... % Если ошибок хватает
                        (obj.NumErFrames(end) >= obj.MinNumErFrames) && ... % И кадров хватает
                        (obj.NumTrFrames(end) >= obj.MinNumTrFrames)) || ... % И кадров передано
                        isComplexityExceeded % Или превышена сложность
                    isPointFinished = true; % Завершить точку
                end
            % Формирование строки лога
                    LogStr = sprintf(['%s     h2 = %', ... % Формат лога
                        obj.strh2NumDigits, '.', obj.strh2Precision, ... % Точность h2
                        'f дБ; h2Step = %', obj.strh2NumDigits, '.', ... % Точность шага
                        obj.strh2Precision, 'f дБ; BER = %0.', ... % Точность BER
                        obj.strBERPrecision, 'f = %', ... % Формат BER
                        obj.strBERNumRateDigits, 'd/%', ... % Формат ошибок
                        obj.strBERNumRateDigits, 'd; FER = %', ... % Формат FER
                        obj.strFERNumRateDigits, 'd/%', ... % Формат ошибок кадров
                        obj.strFERNumRateDigits, 'd\n'], datestr(now), ... % Время
                        obj.h2dB, obj.h2dBStep, obj.NumErBits(end) / ... % Значения
                        obj.NumTrBits(end), obj.NumErBits(end), ... % Значения
                        obj.NumTrBits(end), obj.NumErFrames(end), ... % Значения
                        obj.NumTrFrames(end)); % Значения
                    if strcmp(obj.LogLanguage, 'Russian') % Если русский
                    else % Английский
                        LogStr = strrep(LogStr, 'дБ', 'dB'); % Замена
                    end
                    if isPointFinished % Если точка завершена
                        if strcmp(obj.LogLanguage, 'Russian') % Если русский
                            SubS = ' Завершено'; % Текст завершения
                            if isComplexityExceeded % Если сложность
                                SubS = [SubS, ' (превышена сложность)']; % Добавить
                            end
                        else % Английский
                            SubS = ' Completed'; % Текст завершения
                            if isComplexityExceeded % Если сложность
                                SubS = [SubS, ' (complexity exceeded)']; % Добавить
                            end
                        end                        
                        LogStr = [LogStr(1:end-1), SubS, LogStr(end)]; % Склейка
                    end
                % Сохранение лога
                    for k = 1:2 % Цикл по логам
                        if obj.isRealTimeLog(k) % Если реалтайм
                            obj.Log{k}{end} = LogStr; % Обновить
                        else % Иначе
                            if isPointFinished % Если точка завершена
                                obj.Log{k} = {LogStr}; % Сохранить
                            end
                        end
                    end
            % Проверка завершения основных расчетов
                isMainCalcJustFinished = false; % Флаг завершения
                if isPointFinished && ~obj.isMainCalcFinished % Если точка завершена
                    BER = obj.NumErBits   ./ obj.NumTrBits; % Вычисление BER
                    FER = obj.NumErFrames ./ obj.NumTrFrames; % Вычисление FER
                    if ((BER(end) < obj.MinBER) && ... % Если BER меньше
                        (FER(end) < obj.MinFER)) || ... % И FER меньше
                        isComplexityExceeded % Или сложность
                        obj.isMainCalcFinished = true; % Завершить расчеты
                        obj.h2dBStep = nan; % Сброс шага
                        isMainCalcJustFinished = true; % Флаг завершения
                    end
                    if length(BER) > 1 % Если точек больше 1
                        BERRate = BER(1:end-1) ./ BER(2:end); % Отношение BER
                    else % Иначе
                        BERRate = 0.5*(obj.MinBERRate + obj.MaxBERRate); % Среднее
                    end
                end
            % Расчет следующей точки
                if isPointFinished && ~obj.isMainCalcFinished % Если точка завершена
                    % Корректировка шага h2dBStep
                        if BERRate(end) > obj.MaxBERRate % Если отношение большое
                            RRate = BERRate(end) / obj.MaxBERRate; % Вычисление
                            if                      (RRate <  4) % Если меньше 4
                                DecFact = 1/2; % Коэффициент 1/2
                            elseif (RRate >=  4) && (RRate < 16) % Если 4-16
                                DecFact = 1/4; % Коэффициент 1/4
                            elseif (RRate >= 16) && (RRate < 64) % Если 16-64
                                DecFact = 1/8; % Коэффициент 1/8
                            elseif (RRate >= 64) % Если больше 64
                                DecFact = 1/16; % Коэффициент 1/16
                            end
                            Buf = obj.Round(DecFact*obj.h2dBStep); % Уменьшение шага
                            obj.h2dBStep = max(Buf, obj.h2dBMinStep); % Ограничение
                        elseif BERRate(end) < obj.MinBERRate % Если отношение маленькое
                            Buf = obj.Round(2*obj.h2dBStep); % Увеличение шага
                            obj.h2dBStep = min(Buf, obj.h2dBMaxStep); % Ограничение
                        end
                    % Расчет нового h2dB
                        obj.h2dB = obj.h2dB + obj.h2dBStep; % Прибавление шага
                    % Проверка выхода за h2dBMax
                        if obj.h2dB > obj.h2dBMax % Если больше макс.
                            obj.isMainCalcFinished = true; % Завершить
                            isMainCalcJustFinished = true; % Флаг завершения
                        end
                    % Проверка нулевого шага
                        if obj.h2dBStep < eps % Если шаг мал
                            obj.isMainCalcFinished = true; % Завершить
                            isMainCalcJustFinished = true; % Флаг завершения
                        end
                end
            % Вывод лога о завершении расчетов
                if isMainCalcJustFinished % Если только что завершили
                    if strcmp(obj.LogLanguage, 'Russian') % Если русский
                        LogStr = '   Основные вычисления завершены.'; % Текст
                        if obj.h2dB > obj.h2dBMax % Если выход за макс.
                            LogStr = [LogStr, ' (превышено ', ... % Добавить
                                'максимальное ОСШ)']; % Текст
                        end
                        if obj.h2dBStep < eps % Если нулевой шаг
                            LogStr = [LogStr, ' (получен нулевой шаг h2)']; % Добавить
                        end
                    else % Английский
                        LogStr = '   The main calculations are completed.'; % Текст
                        if obj.h2dB > obj.h2dBMax % Если выход за макс.
                            LogStr = [LogStr, ' (Maximum SNR is ', ... % Добавить
                                'exceeded)']; % Текст
                        end
                        if obj.h2dBStep < eps % Если нулевой шаг
                            LogStr = [LogStr, ' (Zero h2 step obtained)']; % Добавить
                        end
                    end
                    LogStr = sprintf('%s%s\n', datestr(now), LogStr); % Формат
                    for k = 1:2 % Цикл по логам
                        obj.Log{k}{end+1} = LogStr; % Добавить в лог
                    end
                end
            % Удаление лишних точек при превышении сложности
                if isPointFinished && obj.isMainCalcFinished && ... % Если точка завершена
                        isComplexityExceeded && ~isMainCalcJustFinished % И сложность
                    Poses = (obj.h2dBs <= obj.h2dB); % Позиции для удаления
                    obj.h2dBs       = obj.h2dBs      (Poses); % Удаление h2
                    obj.NumTrBits   = obj.NumTrBits  (Poses); % Удаление бит
                    obj.NumTrFrames = obj.NumTrFrames(Poses); % Удаление кадров
                    obj.NumErBits   = obj.NumErBits  (Poses); % Удаление ошибок
                    obj.NumErFrames = obj.NumErFrames(Poses); % Удаление кадров с ошибками
                    NumDeleted1 = length(Poses) - sum(Poses); % Количество удаленных
                    Poses = (obj.Addh2dBs <= obj.h2dB); % Позиции доп. точек
                    obj.Addh2dBs = obj.Addh2dBs(Poses); % Удаление доп. точек
                    NumDeleted2 = length(Poses) - sum(Poses); % Количество удаленных
                    if strcmp(obj.LogLanguage, 'Russian') % Если русский
                        LogStr = sprintf([ ... % Формат
                            '%s     Удалено %d точек из ', ... % Текст
                            'основных вычислений и ', ... % Текст
                            'удалено %d значений h2, ', ... % Текст
                            'предназначенных в ', ... % Текст
                            'дополнительные вычисления.\n'], ... % Текст
                            datestr(now), NumDeleted1, NumDeleted2); % Данные
                    else % Английский
                        LogStr = sprintf([ ... % Формат
                            '%s     %d results are deleted from ', ... % Текст
                            'main calculations and %d values of ', ... % Текст
                            'h2 are deleted from the set for ', ... % Текст
                            'additional calculations .\n'], ... % Текст
                            datestr(now), NumDeleted1, NumDeleted2); % Данные
                    end      
                    for k = 1:2 % Цикл по логам
                        obj.Log{k}{end+1} = LogStr; % Добавить в лог
                    end
                end
            % Логика дополнительных вычислений
                if isPointFinished && obj.isMainCalcFinished % Если точка завершена
                    % Определение новых дополнительных точек
                        if isempty(obj.Addh2dBs) % Если доп. точек нет
                            % Сортировка основных точек
                                [obj.h2dBs, I]  = sort(obj.h2dBs); % Сортировка
                                obj.NumTrBits   = obj.NumTrBits  (I); % Перестановка
                                obj.NumTrFrames = obj.NumTrFrames(I); % Перестановка
                                obj.NumErBits   = obj.NumErBits  (I); % Перестановка
                                obj.NumErFrames = obj.NumErFrames(I); % Перестановка
                            % Вычисление BER и отношений
                                BER = obj.NumErBits ./ obj.NumTrBits; % Вычисление
                                if length(BER) > 1 % Если точек больше 1
                                    BERRate = BER(1:end-1) ./ BER(2:end); % Отношение
                                else % Иначе
                                    BERRate = 0.5*(obj.MinBERRate + ... % Среднее
                                        obj.MaxBERRate); % Значение
                                end
                            % Поиск мест для доп. точек
                                Poses = find(BERRate > obj.MaxBERRate); % Позиции
                                obj.Addh2dBs = (obj.h2dBs(Poses+1) + ... % Среднее
                                    obj.h2dBs(Poses)) / 2; % Значение
                                obj.Addh2dBs = obj.Round(obj.Addh2dBs); % Округление
                            % Проверка размера шага
                                    h2dBSteps = min([obj.Addh2dBs - ... % Мин. шаг
                                        obj.h2dBs(Poses); ... % Из двух
                                        obj.h2dBs(Poses+1) - ... % Значений
                                        obj.Addh2dBs]); % Шага
                                    Poses = (h2dBSteps + 1000*eps >= ... % Если шаг
                                    obj.h2dBMinStep); % Достаточен
                                obj.Addh2dBs = obj.Addh2dBs(Poses); % Фильтрация
                            % Запись в лог
                                if ~isempty(obj.Addh2dBs) % Если точки есть
                                    LogStr = sprintf([' %0.', ... % Формат
                                        obj.strh2Precision, 'f'], ... % Точность
                                        obj.Addh2dBs); % Значения
                                    if strcmp(obj.LogLanguage, 'Russian') % Если русский
                                        LogStr = sprintf([ ... % Формат
                                            '%s   Старт ', ... % Текст
                                            'дополнительных ', ... % Текст
                                            'вычислений [%s].\n'], ... % Текст
                                            datestr(now), LogStr(2:end)); % Данные
                                    else % Английский
                                        LogStr = sprintf([ ... % Формат
                                            '%s   Start of the ', ... % Текст
                                            'additional calculations ', ... % Текст
                                            '[%s].\n'], datestr(now), ... % Текст
                                            LogStr(2:end)); % Данные
                                    end      
                                    for k = 1:2 % Цикл по логам
                                        obj.Log{k}{end+1} = LogStr; % Добавить в лог
                                    end
                                end
                        end
                    % Завершение или выбор следующей точки
                        if isempty(obj.Addh2dBs) % Если точек нет
                            obj.isStop = true; % Остановка
                            if ~isMainCalcJustFinished % Если не только что
                                if strcmp(obj.LogLanguage, 'Russian') % Если русский
                                    LogStr = sprintf(['%s   ', ... % Формат
                                        'Дополнительные ', ... % Текст
                                        'вычисления завершены.\n'], ... % Текст
                                        datestr(now)); % Данные
                                else % Английский
                                    LogStr = sprintf(['%s   ', ... % Формат
                                        'The additional ', ... % Текст
                                        'calculations are ', ... % Текст
                                        'completed.\n'], datestr(now)); % Данные
                                end
                                for k = 1:2 % Цикл по логам
                                    obj.Log{k}{end+1} = LogStr; % Добавить в лог
                                end
                            end
                            if strcmp(obj.LogLanguage, 'Russian') % Если русский
                                LogStr = sprintf(['%s ', ... % Формат
                                    'Вычисления завершены.\n'], ... % Текст
                                    datestr(now)); % Данные
                            else % Английский
                                LogStr = sprintf(['%s ', ... % Формат
                                    'Calculations are ', ... % Текст
                                    'completed.\n'], datestr(now)); % Данные
                            end
                            for k = 1:2 % Цикл по логам
                                obj.Log{k}{end+1} = LogStr; % Добавить
                                obj.Log{k}{end+1} = newline; % Пустая строка
                            end
                        else % Если точки есть
                            obj.h2dB = obj.Addh2dBs(1); % Взять первую
                            obj.Addh2dBs = obj.Addh2dBs(2:end); % Удалить из списка
                        end
                end
            % Сохранение результатов текущей точки
                if isPointFinished && ~obj.isStop % Если точка завершена
                    obj.h2dBs       = [obj.h2dBs, obj.h2dB]; % Добавить h2
                    obj.NumTrBits   = [obj.NumTrBits,   0]; % Сброс бит
                    obj.NumTrFrames = [obj.NumTrFrames, 0]; % Сброс кадров
                    obj.NumErBits   = [obj.NumErBits,   0]; % Сброс ошибок
                    obj.NumErFrames = [obj.NumErFrames, 0]; % Сброс кадров с ошибками
                    obj.ResetRandStreams(); % Сброс генераторов
                end
            % Вывод лога
                for k = 1:2 % Цикл по логам
                    obj.PrintLog(k, obj.isRealTimeLog(k)); % Печать
                    if obj.isRealTimeLog(k) % Если реалтайм
                        if isPointFinished && ~obj.isStop % Если точка завершена
                            obj.Log{k}{end+1} = ''; % Пустая строка
                        end
                    else % Иначе
                        obj.Log{k} = cell(0); % Очистка
                    end
                end
        end
        function Saves(obj, Objs, Params) %#ok<INUSL> % Сохранение результатов
            Res.h2dBs       = obj.h2dBs; % Массив h2
            Res.NumErBits   = obj.NumErBits; % Ошибки
            Res.NumTrBits   = obj.NumTrBits; % Биты
            Res.NumErFrames = obj.NumErFrames; % Кадры с ошибками
            Res.NumTrFrames = obj.NumTrFrames; % Кадры
            save(obj.FullSaveFileName, 'Res', 'Params'); % Сохранение в файл
        end
        function StartParallel(obj) % Запуск параллельных вычислений
            P = gcp('nocreate'); % Проверка пула
            isOk = false; % Флаг готовности
                if ~isempty(P) % Если пул есть
                    if P.Connected % Если подключен
                        if isequal(P.NumWorkers, obj.NumWorkers) % Если число совпадает
                            isOk = true; % Установить флаг
                        end
                    end
                else % Если пула нет
                    if isequal(obj.NumWorkers, 1) % Если 1 воркер
                        isOk = true; % Флаг готовности
                    end
                end
                if ~isOk % Если не готов
                        if ~isempty(P) % Если пул есть
                            delete(P); % Удалить
                        end
                    if obj.NumWorkers > 1 % Если нужно больше 1
                            P = parpool(obj.NumWorkers); % Создать пул
                            isOk = false; % Сброс флага
                            if P.Connected % Если подключен
                                if isequal(P.NumWorkers, obj.NumWorkers) % Если число совпадает
                                    isOk = true; % Установить флаг
                                end
                            end
                            if ~isOk % Если не готов
                                if strcmp(obj.LogLanguage, 'Russian') % Если русский
                                    error(['Не удалось запустить ', ... % Ошибка
                                        'pool с заданными параметрами']); % Текст
                                else % Английский
                                    error(['Failed to start the pool ', ... % Ошибка
                                        'with the specified parameters']); % Текст
                                end
                            end
                    end
                end
        end
        function StopParallel(obj) %#ok<MANU> % Остановка параллельных вычислений
            P = gcp('nocreate'); % Получение пула
                if ~isempty(P) % Если пул есть
                    delete(P); % Удалить
                end
        end
        function ResetRandStreams(obj) % Сброс генераторов случайных чисел
            if obj.NumWorkers > 1 % Если параллельно
                spmd % Параллельно
                    Stream = RandStream.getGlobalStream; % Получить поток
                    reset(Stream); % Сбросить
                end
            else % Если последовательно
                Stream = RandStream.getGlobalStream; % Получить поток
                reset(Stream); % Сбросить
            end
        end
        function PrintLog(obj, LogNum, isClear) % Печать лога
            if isempty(obj.Log{LogNum}) % Если лог пуст
                return % Выход
            end
            if LogNum == 1 % Если окно
                if isClear % Если очищать
                    clc; % Очистить
                end
                for k = 1:length(obj.Log{1}) % Цикл по строкам
                    fprintf('%s', obj.Log{1}{k}); % Печать
                end
            elseif LogNum == 2 % Если файл
                if isClear % Если очищать
                    fileID = fopen(obj.FullLogFileName, 'w'); % Открыть на запись
                else % Иначе
                    fileID = fopen(obj.FullLogFileName, 'a'); % Открыть на дополнение
                end
                if fileID < 0 % Если ошибка
                    if strcmp(obj.LogLanguage, 'Russian') % Если русский
                        error(['Не удалось открыть файл для ', ... % Ошибка
                            'сохранения лога!']); % Текст
                    else % Английский
                        error('Failed to open file to save log!'); % Ошибка
                    end
                end
                for k = 1:length(obj.Log{2}) % Цикл по строкам
                    fprintf(fileID, '%s\r\n', obj.Log{2}{k}(1:end-1)); % Запись
                end
                fclose(fileID); % Закрыть файл
            end
        end
        function Out = Round(obj, In) % Округление
            Out = round(10^obj.h2Precision*In) / 10^obj.h2Precision; % Формула
        end
    end
end
