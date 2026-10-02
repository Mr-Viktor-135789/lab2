classdef ClassBERRuler < handle
    properties (SetAccess = private) % Переменные из параметров
    % Параметры работы BERRuler
        % Из Common
            SaveFileName;
            SaveDirName;
            NumOneIterFrames;
            NumWorkers;
            isRealTimeLog;
        % Из BER
            h2Precision;
            BERPrecision;
            BERNumRateDigits;
            FERNumRateDigits;

            MinNumTrFrames;

            h2dBInit;
            h2dBInitStep;
            h2dBMaxStep;
            h2dBMinStep;
            h2dBMax;

            MinBER;
            MinNumErBits;
            MinFER;
            MinNumErFrames;

            MaxNumTrBits
            MaxNumTrFrames

            MaxBERRate;
            MinBERRate;
        % Переменная управления языком вывода информации для пользователя
            LogLanguage;
    end
    properties (SetAccess = private) % Переменные, используемые снаружи
        h2dB;  
        isStop;
        OneWorkerNumOneIterFrames;
    end
    properties (SetAccess = private) % Внутренние переменные
        strh2Precision;
        strh2NumDigits;
        strBERPrecision;
        strBERNumRateDigits;
        strFERNumRateDigits;
    end    
    properties (SetAccess = private) % Переменные, используемые для
    % накопления статистики
        h2dBs;
        NumTrBits;
        NumTrFrames;
        NumErBits;
        NumErFrames;
    end
    properties (SetAccess = private) % Параметры, используемые для перехода
    % между состояниями расчёта кривой помехоустойчивости, лог и полные
    % имена файлов для сохранения
        isMainCalcFinished;
        h2dBStep;
        Addh2dBs;
        Log;
        FullSaveFileName;
        FullLogFileName;
    end
    methods
        function obj = ClassBERRuler(Params, ParamsNum, NumParams, ...
                LogLanguage) % Конструктор
            % Выделим поля Params, необходимые для инициализации
                Common = Params.Common;
                BER    = Params.BER;
            % Инициализация параметров работы из Common
                obj.SaveFileName     = Common.SaveFileName;
                obj.SaveDirName      = Common.SaveDirName;
                obj.NumOneIterFrames = Common.NumOneIterFrames;
                obj.NumWorkers       = Common.NumWorkers;
                obj.isRealTimeLog(1) = Common.isRealTimeLogCWin;
                obj.isRealTimeLog(2) = Common.isRealTimeLogFile;
            % Инициализация параметров работы из BER
                obj.h2Precision      = BER.h2Precision;
                obj.BERPrecision     = BER.BERPrecision;
                obj.BERNumRateDigits = BER.BERNumRateDigits;
                obj.FERNumRateDigits = BER.FERNumRateDigits;
            
                obj.MinNumTrFrames   = BER.MinNumTrFrames;

                obj.h2dBInit         = BER.h2dBInit;
                obj.h2dBInitStep     = BER.h2dBInitStep;
                obj.h2dBMaxStep      = BER.h2dBMaxStep;
                obj.h2dBMinStep      = BER.h2dBMinStep;
                obj.h2dBMax          = BER.h2dBMax;

                obj.MinBER           = BER.MinBER;
                obj.MinNumErBits     = BER.MinNumErBits;
                obj.MinFER           = BER.MinFER;
                obj.MinNumErFrames   = BER.MinNumErFrames;

                obj.MaxNumTrBits     = BER.MaxNumTrBits;
                obj.MaxNumTrFrames   = BER.MaxNumTrFrames;

                obj.MaxBERRate       = BER.MaxBERRate;
                obj.MinBERRate       = BER.MinBERRate;
            % Переменная LogLanguage
                obj.LogLanguage = LogLanguage;

            % Инициализация параметров, используемых снаружи: h2dB и isStop
                obj.h2dB   = obj.h2dBInit;
                obj.isStop = false;

            % Определим строковые аналоги чисел, управляющих количеством
            % разрядов значений при выводе лога
                obj.strh2Precision      = sprintf('%d', obj.h2Precision);
                if obj.h2Precision == 0
                    obj.strh2NumDigits      = sprintf('%d', ...
                        obj.h2Precision + 2);
                else
                    obj.strh2NumDigits      = sprintf('%d', ...
                        obj.h2Precision + 3);
                end
                obj.strBERPrecision     = sprintf('%d', obj.BERPrecision);
                obj.strBERNumRateDigits = sprintf('%d', ...
                    obj.BERNumRateDigits);
                obj.strFERNumRateDigits = sprintf('%d', ...
                    obj.FERNumRateDigits);

            % Округлим все значения h2
                obj.h2dBInit     = obj.Round(obj.h2dBInit);
                obj.h2dBInitStep = obj.Round(obj.h2dBInitStep);
                obj.h2dBMaxStep  = obj.Round(obj.h2dBMaxStep);
                obj.h2dBMinStep  = obj.Round(obj.h2dBMinStep);
                obj.h2dBMax      = obj.Round(obj.h2dBMax);

            % Определение числа кадров, обрабатываемых за одну итерацию для
            % каждого worker
                obj.OneWorkerNumOneIterFrames = zeros(1, ...
                    Common.NumWorkers) + round(Common.NumOneIterFrames ...
                    / Common.NumWorkers);
                obj.OneWorkerNumOneIterFrames(end) = ...
                    Common.NumOneIterFrames - ...
                    sum(obj.OneWorkerNumOneIterFrames(1:end-1));

            % Инициализация параметров, используемых для накопления
            % статистики
                obj.h2dBs       = obj.h2dB;
                obj.NumTrBits   = 0;
                obj.NumTrFrames = 0;
                obj.NumErBits   = 0;
                obj.NumErFrames = 0;

            % Инициализация параметров, используемых для перехода между
            % состояниями расчёта кривой помехоустойчивости
                obj.isMainCalcFinished = false;
                obj.h2dBStep = obj.h2dBInitStep;
                obj.Addh2dBs = [];
                
            % При необходимости создадим папку для сохранения результатов
                if ~isfolder(obj.SaveDirName)
                    mkdir(obj.SaveDirName);
                end

            % Имя файла для сохранения лога
                if isunix % Linux platform
                    % Code to run on Linux platform
                    PathDelimiter = '/';
                elseif ispc % Windows platform
                    % Code to run on Windows platform
                    PathDelimiter = '\';
                else
                    if strcmp(obj.LogLanguage, 'Russian')
                        error('Не удаётся определить платформу!');
                    else
                        error('Cannot recognize platform!');
                    end
                end            
                obj.FullLogFileName = [obj.SaveDirName, PathDelimiter, ...
                    obj.SaveFileName, '.log'];
                
            % Имя файла для сохранения результатов
                obj.FullSaveFileName = [obj.SaveDirName, PathDelimiter, ...
                    obj.SaveFileName, '.mat'];
                
            % Лог
            % На самом деле ведутся два лога, первый для вывода на экран,
            % второй - для сохранения в файл
                % Первая строка
                    if strcmp(obj.LogLanguage, 'Russian')
                        LogStr1 = sprintf(['%s Старт вычисления ', ...
                            'кривой %s (%d из %d).\n'], datestr(now), ...
                            obj.SaveFileName, ParamsNum, NumParams);
                    else
                        LogStr1 = sprintf(['%s Start of calculation ', ...
                            'the curve %s (%d of %d).\n'], ...
                            datestr(now), obj.SaveFileName, ParamsNum, ...
                            NumParams);
                    end
                % Вторая строка
                    if strcmp(obj.LogLanguage, 'Russian')
                        LogStr2 = sprintf(['%s   Старт основных ', ...
                            'вычислений.\n'], datestr(now));
                    else
                        LogStr2 = sprintf(['%s   Start of the ', ...
                            'main calculations.\n'], datestr(now));
                    end                        

                % Сохраним строки в лог
                    obj.Log = cell(2, 1); % заготовка под два лога
                    obj.Log{1} = {LogStr1; LogStr2};
                    obj.Log{2} = obj.Log{1}; % копируем первый лог во
                        % второй

                    for k = 1:2
                        if k == 1
                            obj.PrintLog(k, obj.isRealTimeLog(k));
                        else
                            obj.PrintLog(k, 1);
                        end
                        if obj.isRealTimeLog(k)
                            % Заготовка для следующей строки
                            obj.Log{k}{3} = '';
                        else
                            obj.Log{k} = cell(0);
                        end
                    end
        end
        function isPointFinished = Step(obj, Objs)
            % Обновление статистики
                for k = 1:length(Objs)
                    obj.NumTrBits(end)   = obj.NumTrBits(end)   + ...
                        Objs{k}.Stat.NumTrBits;
                    obj.NumTrFrames(end) = obj.NumTrFrames(end) + ...
                        Objs{k}.Stat.NumTrFrames;
                    
                    obj.NumErBits(end)   = obj.NumErBits(end)   + ...
                        Objs{k}.Stat.NumErBits;
                    obj.NumErFrames(end) = obj.NumErFrames(end) + ...
                        Objs{k}.Stat.NumErFrames;
                    
                    Objs{k}.Stat.Reset();
                end

            % Определим, превышена ли сложность расчёта одной точки
                isComplexityExceeded = false;
                if (obj.NumTrBits(end) > obj.MaxNumTrBits) || ...
                        (obj.NumTrFrames(end) > obj.MaxNumTrFrames)
                    isComplexityExceeded = true;
                end
            
            % Определим закончен ли расчёт для текущей точки - либо
            % достигнуты минимальные показатели, либо превышена сложность
            % расчёта
                isPointFinished = false;
                if ((obj.NumErBits(end) >= obj.MinNumErBits) && ...
                        (obj.NumErFrames(end) >= obj.MinNumErFrames) && ...
                        (obj.NumTrFrames(end) >= obj.MinNumTrFrames)) || ...
                        isComplexityExceeded
                    isPointFinished = true;
                end

            % Лог
                % Новая строка
                    LogStr = sprintf(['%s     h2 = %', ...
                        obj.strh2NumDigits, '.', obj.strh2Precision, ...
                        'f дБ; h2Step = %', obj.strh2NumDigits, '.', ...
                        obj.strh2Precision, 'f дБ; BER = %0.', ...
                        obj.strBERPrecision, 'f = %', ...
                        obj.strBERNumRateDigits, 'd/%', ...
                        obj.strBERNumRateDigits, 'd; FER = %', ...
                        obj.strFERNumRateDigits, 'd/%', ...
                        obj.strFERNumRateDigits, 'd\n'], datestr(now), ...
                        obj.h2dB, obj.h2dBStep, obj.NumErBits(end) / ...
                        obj.NumTrBits(end), obj.NumErBits(end), ...
                        obj.NumTrBits(end), obj.NumErFrames(end), ...
                        obj.NumTrFrames(end));
                    if strcmp(obj.LogLanguage, 'Russian')
                    else
                        LogStr = strrep(LogStr, 'дБ', 'dB');
                    end

                    if isPointFinished
                        if strcmp(obj.LogLanguage, 'Russian')
                            SubS = ' Завершено';
                            if isComplexityExceeded
                                SubS = [SubS, ' (превышена сложность)'];
                            end
                        else
                            SubS = ' Completed';
                            if isComplexityExceeded
                                SubS = [SubS, ' (complexity exceeded)'];
                            end
                        end                        
                        LogStr = [LogStr(1:end-1), SubS, LogStr(end)];
                    end

                % Добавим новую строку к логу
                    for k = 1:2
                        if obj.isRealTimeLog(k)
                            obj.Log{k}{end} = LogStr;
                        else
                            if isPointFinished
                                obj.Log{k} = {LogStr};
                            end
                        end
                    end

            % Если мы находимся в основном расчёте, то по значениям BER,
            % FER и isComplexityExceeded проверим, не завершился ли он
                isMainCalcJustFinished = false; % для нужд лога
                if isPointFinished && ~obj.isMainCalcFinished
                    BER = obj.NumErBits   ./ obj.NumTrBits;
                    FER = obj.NumErFrames ./ obj.NumTrFrames;
                    
                    if ((BER(end) < obj.MinBER) && ...
                        (FER(end) < obj.MinFER)) || ...
                        isComplexityExceeded
                        obj.isMainCalcFinished = true;
                        obj.h2dBStep = nan; % Формально
                        isMainCalcJustFinished = true; % для нужд лога
                    end
                    
                    if length(BER) > 1
                        BERRate = BER(1:end-1) ./ BER(2:end);
                    else
                        BERRate = 0.5*(obj.MinBERRate + obj.MaxBERRate);
                    end
                end
                
            % Переход к новой точке для случая основного расчёта точек
                if isPointFinished && ~obj.isMainCalcFinished
                    % Обновим значение h2dBStep
                        if BERRate(end) > obj.MaxBERRate
                            % Вариант 1: стандартный
                                % Buf = obj.Round(0.5*obj.h2dBStep);
                                % obj.h2dBStep = max(Buf, obj.h2dBMinStep);
                            % Вариант 2: лучше ралботает в случае
                            % эффективных помехоустойчивых кодов
                                RRate = BERRate(end) / obj.MaxBERRate;
                                if                      (RRate <  4)
                                    DecFact = 1/2;
                                elseif (RRate >=  4) && (RRate < 16)
                                    DecFact = 1/4;
                                elseif (RRate >= 16) && (RRate < 64)
                                    DecFact = 1/8;
                                elseif (RRate >= 64)
                                    DecFact = 1/16;
                                end
                                Buf = obj.Round(DecFact*obj.h2dBStep);
                                obj.h2dBStep = max(Buf, obj.h2dBMinStep);
                        elseif BERRate(end) < obj.MinBERRate
                            Buf = obj.Round(2*obj.h2dBStep);
                            obj.h2dBStep = min(Buf, obj.h2dBMaxStep);
                        end
                    % обновим значение h2dB
                        obj.h2dB = obj.h2dB + obj.h2dBStep;
                    % Проверим не превышено ли значение h2dBMax
                        if obj.h2dB > obj.h2dBMax
                            obj.isMainCalcFinished = true;
                            isMainCalcJustFinished = true; % для нужд лога
                        end
                    % Проверим, не получилось ли из-за округлений
                    % obj.h2dBStep = 0
                        if obj.h2dBStep < eps
                            obj.isMainCalcFinished = true;
                            isMainCalcJustFinished = true; % для нужд лога
                        end
                end
                
            % Лог
                if isMainCalcJustFinished
                    if strcmp(obj.LogLanguage, 'Russian')
                        LogStr = '   Основные вычисления завершены.';
                        if obj.h2dB > obj.h2dBMax
                            LogStr = [LogStr, ' (Превышено ', ...
                                'максимальное ОСШ)'];
                        end
                        if obj.h2dBStep < eps
                            LogStr = [LogStr, ' (Получен нулевой шаг h2)'];
                        end
                    else
                        LogStr = '   The main calculations are completed.';
                        if obj.h2dB > obj.h2dBMax
                            LogStr = [LogStr, ' (Maximum SNR is ', ...
                                'exceeded)'];
                        end
                        if obj.h2dBStep < eps
                            LogStr = [LogStr, ' (Zero h2 step obtained)'];
                        end
                    end
                    LogStr = sprintf('%s%s\n', datestr(now), LogStr);
                    for k = 1:2
                        obj.Log{k}{end+1} = LogStr;
                    end
                end
                
            % Если мы находимся в расчёте дополнительных точек и расчёт
            % очередной точки завершился из-за превышения сложности, то
            % нужно отбросить все точки с большими значениями h2
                if isPointFinished && obj.isMainCalcFinished && ...
                        isComplexityExceeded && ~isMainCalcJustFinished
                    % Выкенем результаты с большими значениями h2
                        Poses = (obj.h2dBs <= obj.h2dB);
                        obj.h2dBs       = obj.h2dBs      (Poses);
                        obj.NumTrBits   = obj.NumTrBits  (Poses);
                        obj.NumTrFrames = obj.NumTrFrames(Poses);
                        obj.NumErBits   = obj.NumErBits  (Poses);
                        obj.NumErFrames = obj.NumErFrames(Poses);
                        NumDeleted1 = length(Poses) - sum(Poses);
                    % Выкенем из рассмотрения лишние Addh2dBs
                        Poses = (obj.Addh2dBs <= obj.h2dB);
                        obj.Addh2dBs = obj.Addh2dBs(Poses);
                        NumDeleted2 = length(Poses) - sum(Poses);
                    % Лог
                        if strcmp(obj.LogLanguage, 'Russian')
                            LogStr = sprintf([ ...
                                '%s     Удалено %d точек из ', ...
                                'результатов основных вычислений и ', ...
                                'удалено %d значений h2, ', ...
                                'предполагавшихся к рассмотрению в ', ...
                                'дополнительных вычислениях.\n'], ...
                                datestr(now), NumDeleted1, NumDeleted2);
                        else
                            LogStr = sprintf([ ...
                                '%s     %d results are deleted from ', ...
                                'main calculations and %d values of ', ...
                                'h2 are deleted from the set for ', ...
                                'additional calculations .\n'], ...
                                datestr(now), NumDeleted1, NumDeleted2);
                        end      
                        for k = 1:2
                            obj.Log{k}{end+1} = LogStr;
                        end
                end
                
            % Переход к новой точке для случая расчёта дополнительных точек
                if isPointFinished && obj.isMainCalcFinished
                    % Определим требуемые для расчёта дополнительные
                    % значения h2dB или будем использовать расчитанные
                    % ранее
                        if isempty(obj.Addh2dBs)
                            % Сортировка результата по возрастанию h2dBs
                                [obj.h2dBs, I]  = sort(obj.h2dBs);
                                obj.NumTrBits   = obj.NumTrBits  (I);
                                obj.NumTrFrames = obj.NumTrFrames(I);
                                obj.NumErBits   = obj.NumErBits  (I);
                                obj.NumErFrames = obj.NumErFrames(I);
                            % Вычисление BER и BERRate
                                BER = obj.NumErBits ./ obj.NumTrBits;
                                if length(BER) > 1
                                    BERRate = BER(1:end-1) ./ BER(2:end);
                                else
                                    BERRate = 0.5*(obj.MinBERRate + ...
                                        obj.MaxBERRate);
                                end
                            % Найдём места, где надо расчитать
                            % дополнительные точки
                                Poses = find(BERRate > obj.MaxBERRate);
                                obj.Addh2dBs = (obj.h2dBs(Poses+1) + ...
                                    obj.h2dBs(Poses)) / 2;
                                obj.Addh2dBs = obj.Round(obj.Addh2dBs);
                            % Отбросим те случаи, где получилось
                            % слишком маленькое значение шага по оси h2
                                % Вариант 1 расчёта значений шага
                                    % h2dBSteps = (obj.h2dBs(Poses+1) - ...
                                    %     obj.h2dBs(Poses)) / 2;
                                % Вариант 2 расчёта значений шага
                                    h2dBSteps = min([obj.Addh2dBs - ...
                                        obj.h2dBs(Poses); ...
                                        obj.h2dBs(Poses+1) - ...
                                        obj.Addh2dBs]);
                                    % Вариант 2 - более стабильный из-за
                                    % округления obj.Addh2dBs
                                Poses = (h2dBSteps + 1000*eps >= ...
                                    obj.h2dBMinStep);
                                    % + 1000*eps для более стабильной
                                    % работы в случае, если h2dBSteps равно
                                    % obj.h2dBMinStep
                                obj.Addh2dBs = obj.Addh2dBs(Poses);
                            % Разберёмся с логом
                                if ~isempty(obj.Addh2dBs)
                                    LogStr = sprintf([' %0.', ...
                                        obj.strh2Precision, 'f'], ...
                                        obj.Addh2dBs);
                                    if strcmp(obj.LogLanguage, 'Russian')
                                        LogStr = sprintf([ ...
                                            '%s   Старт ', ...
                                            'дополнительных ', ...
                                            'вычислений [%s].\n'], ...
                                            datestr(now), LogStr(2:end));
                                    else
                                        LogStr = sprintf([ ...
                                            '%s   Start of the ', ...
                                            'additional calculations ', ...
                                            '[%s].\n'], datestr(now), ...
                                            LogStr(2:end));
                                    end      
                                    for k = 1:2
                                        obj.Log{k}{end+1} = LogStr;
                                    end
                                end
                        end

                    % Переходим к очередному значению Addh2dBs
                        if isempty(obj.Addh2dBs)
                            obj.isStop = true;

                            % Лог
                                if ~isMainCalcJustFinished
                                    if strcmp(obj.LogLanguage, 'Russian')
                                        LogStr = sprintf(['%s   ', ...
                                            'Дополнительные ', ...
                                            'вычисления завершены.\n'], ...
                                            datestr(now));
                                    else
                                        LogStr = sprintf(['%s   ', ...
                                            'The additional ', ...
                                            'calculations are ', ...
                                            'completed.\n'], datestr(now));
                                    end
                                    for k = 1:2
                                        obj.Log{k}{end+1} = LogStr;
                                    end
                                end
                                if strcmp(obj.LogLanguage, 'Russian')
                                    LogStr = sprintf(['%s ', ...
                                        'Вычисления завершены.\n'], ...
                                        datestr(now));
                                else
                                    LogStr = sprintf(['%s ', ...
                                        'Calculations are ', ...
                                        'completed.\n'], datestr(now));
                                end
                                for k = 1:2
                                    obj.Log{k}{end+1} = LogStr;
                                    obj.Log{k}{end+1} = newline;
                                end
                        else
                            obj.h2dB = obj.Addh2dBs(1);
                            obj.Addh2dBs = obj.Addh2dBs(2:end);
                        end
                end

            % Подготовка к расчёту новой точки - добавление нового элемента
            % в массивы и сброс генераторов случайных чисел в начальное
            % состояние
                if isPointFinished && ~obj.isStop
                    obj.h2dBs       = [obj.h2dBs, obj.h2dB];
                    obj.NumTrBits   = [obj.NumTrBits,   0];
                    obj.NumTrFrames = [obj.NumTrFrames, 0];
                    obj.NumErBits   = [obj.NumErBits,   0];
                    obj.NumErFrames = [obj.NumErFrames, 0];
                    obj.ResetRandStreams();
                end
                
            % Вывод лога на экран и сохранение лога в файл
                for k = 1:2
                    obj.PrintLog(k, obj.isRealTimeLog(k));
                    if obj.isRealTimeLog(k)
                        if isPointFinished && ~obj.isStop
                            obj.Log{k}{end+1} = '';
                        end
                    else
                        obj.Log{k} = cell(0);
                    end
                end
        end
        function Saves(obj, Objs, Params) %#ok<INUSL>
            % Можно просто сохранять все объекты и параметры:
            % save(obj.FullSaveFileName, 'Objs', 'obj', 'Params');
            % Однако в этом случае нужно будет обеспечивать наличие
            % описаний классов при загрузке конструкторов в поле видимости
            % MATLAB. Удобнее идти по другому пути - сохранять кривые
            % помехоустойчивости и все параметры. Более того, если в
            % параметрах оказываются какие-нибудь очень большие массивы или
            % структуры, то их лучше предварительно удалять.
            Res.h2dBs       = obj.h2dBs;
            Res.NumErBits   = obj.NumErBits;
            Res.NumTrBits   = obj.NumTrBits;
            Res.NumErFrames = obj.NumErFrames;
            Res.NumTrFrames = obj.NumTrFrames;
            save(obj.FullSaveFileName, 'Res', 'Params');
        end
        function StartParallel(obj)
        %
        % Переход в режим параллельных вычислений (при необходимости)

            % Определим параметры запущенного pool, если он есть
                P = gcp('nocreate');

            % Если pool есть, то он должен быть подключенным и количество
            % worker должно совпадать с требуемым. Если pool отсутствует,
            % то количество требуемых worker должно быть равно 1.
                % Флаг соответствия запущенного pool нужным параметрам
                    isOk = false;
                if ~isempty(P)
                    if P.Connected
                        if isequal(P.NumWorkers, obj.NumWorkers)
                            isOk = true;
                        end
                    end
                else
                    if isequal(obj.NumWorkers, 1)
                        isOk = true;
                    end
                end

            % Если имеющийся pool не соответствует заданным параметрам или
            % его нет, то нужно его создать
                if ~isOk
                    % Удалим pool, если он есть
                        if ~isempty(P)
                            delete(P);
                        end

                    if obj.NumWorkers > 1
                        % Попытаемся создать pool
                            P = parpool(obj.NumWorkers);

                        % Проверим, что удалось создать правильный pool
                            isOk = false;
                            if P.Connected
                                if isequal(P.NumWorkers, obj.NumWorkers)
                                    isOk = true;
                                end
                            end

                        % Если не удалось, выводим ошибку
                            if ~isOk
                                if strcmp(obj.LogLanguage, 'Russian')
                                    error(['Не удалось запустить ', ...
                                        'pool с заданными параметрами']);
                                else
                                    error(['Failed to start the pool ', ...
                                        'with the specified parameters']);
                                end
                            end
                    end
                end

        end
        function StopParallel(obj) %#ok<MANU>
        % Выход из параллельных вычислений (при необходимости)

            % Определим параметры запущенного pool, если он есть
                P = gcp('nocreate');

            % Если имеется pool, то его нужно удалить
                if ~isempty(P)
                    delete(P);
                end
        end
        function ResetRandStreams(obj)
        % Функция сброса генераторов случайных чисел в начальное состояние
            if obj.NumWorkers > 1
                spmd
                    Stream = RandStream.getGlobalStream;
                    reset(Stream);
                end
            else
                Stream = RandStream.getGlobalStream;
                reset(Stream);
            end
        end
        function PrintLog(obj, LogNum, isClear)
        % Вывод на экран/запись в файл лога номер LogNum, где LogNum = 1
        % соответствует экрану, а LogNum = 2 - файлу. isClear - флаг
        % необходимости очистки экрана/файла.
            if isempty(obj.Log{LogNum})
                return
            end
            
            if LogNum == 1 % Вывод лога на экран
                if isClear
                    clc;
                end

                for k = 1:length(obj.Log{1})
                    fprintf('%s', obj.Log{1}{k});
                end
            elseif LogNum == 2 % Сохранение лога в файл
                if isClear
                    fileID = fopen(obj.FullLogFileName, 'w');
                else
                    fileID = fopen(obj.FullLogFileName, 'a');
                end

                if fileID < 0
                    if strcmp(obj.LogLanguage, 'Russian')
                        error(['Не удалось открыть файл для ', ...
                            'сохранения лога!']);
                    else
                        error('Failed to open file to save log!');
                    end
                end

                for k = 1:length(obj.Log{2})
                    fprintf(fileID, '%s\r\n', obj.Log{2}{k}(1:end-1));
                end

                fclose(fileID);
            end
        end
        function Out = Round(obj, In)
        % Функция округления числа до заданного числа десятичных знаков
        % после запятой
            Out = round(10^obj.h2Precision*In) / 10^obj.h2Precision;
        end
    end
end