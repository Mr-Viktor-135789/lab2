function Params = SetParams(inParams, ParamsNumber, LogLanguage)

    % Пересохраним входные данные
        Params = inParams;

    % Имена полей структуры Params верхнего уровня    
        FieldNames = { ...
            'Source', ...
            'Encoder', ...
            'Interleaver', ...
            'Mapper', ...
            'Sig', ...
            'Channel', ...
            'BER', ...
            'Common' ...
        };

    for n = 1:length(FieldNames) % Цикл по всем полям Params верхнего
            % уровня
        % Если поле верхнего уровня не существует, его надо создать
            if ~isfield(Params, FieldNames{n})
                Params.(FieldNames{n}) = [];
            end
        % Сделаем указатель на функцию
            Fun = str2func(['SetParams', FieldNames{n}]);
        % Вызов функции, инициализирующей параметры нижнего уровня
            Params.(FieldNames{n}) = Fun(Params.(FieldNames{n}), ...
                ParamsNumber, LogLanguage);
    end

end
function Source = SetParamsSource(inSource, ParamsNumber, ...
    LogLanguage) %#ok<INUSL,DEFNU>

    % Пересохраним входные данные
        Source = inSource;
        
    % Количество бит, передаваемых в одном кадре
        if ~isfield(Source, 'NumBitsPerFrame')
            Source.NumBitsPerFrame = 1000;
        else
            % Проверка корректности введённых значений
            if Source.NumBitsPerFrame < 1
                if strcmp(LogLanguage, 'Russian')
                    error('Недопустимое значение Source.NumBitsPerFrame');
                else
                    error('Invalid value Source.NumBitsPerFrame');
                end
            end
        end
end
function Encoder = SetParamsEncoder(inEncoder, ParamsNumber, ...
    LogLanguage) %#ok<INUSD,DEFNU>

    % Пересохраним входные данные
        Encoder = inEncoder;

    % Нужно ли выполнять кодирование и декодирование
        if ~isfield(Encoder, 'isTransparent')
            Encoder.isTransparent = true;
        else
            % Проверка корректности введённых значений
        end

    % Следующие переменные вычисляются в CalcAndCheckParams():
        % isSoftInput;
end
function Interleaver = SetParamsInterleaver(inInterleaver, ...
    ParamsNumber, LogLanguage) %#ok<INUSD,DEFNU>

    % Пересохраним входные данные
        Interleaver = inInterleaver;

    % Нужно ли выполнять перемежение и деперемежение
        if ~isfield(Interleaver, 'isTransparent')
            Interleaver.isTransparent = true;
        else
            % Проверка корректности введённых значений
        end
end
function Mapper = SetParamsMapper(inMapper, ParamsNumber, ...
    LogLanguage) %#ok<INUSL,DEFNU>

    % Пересохраним входные данные
        Mapper = inMapper;

    % Нужно ли выполнять модуляцию и демодуляцию
        if ~isfield(Mapper, 'isTransparent')
            Mapper.isTransparent = true;
        else
            % Проверка корректности введённых значений
        end

    % Тип сигнального созвездия: QAM | PSK
        if ~isfield(Mapper, 'Type')
            Mapper.Type = 'QAM';
        else
            if ~(strcmp(Mapper.Type, 'QAM') || ...
                    strcmp(Mapper.Type, 'PSK'))
                if strcmp(LogLanguage, 'Russian')
                    error('Недопустимое значение Mapper.Type');
                else
                    error('Invalid value Mapper.Type');
                end
            end
        end
    
    % Размер сигнального созвездия
        if ~isfield(Mapper, 'ModulationOrder')
            Mapper.ModulationOrder = 4;
        else
            % Проверка корректности введённых значений
        end
        
    % Ротация сигнального созвездия
        if ~isfield(Mapper, 'PhaseOffset')
            Mapper.PhaseOffset = 0;
        else
            % Проверка корректности введённых значений
        end
        
    % Тип отображения бит на точки сигнального созвездия: Binary | Gray
        if ~isfield(Mapper, 'SymbolMapping')
            Mapper.SymbolMapping = 'Gray';
        else
            if ~(strcmp(Mapper.SymbolMapping, 'Binary') || ...
                    strcmp(Mapper.SymbolMapping, 'Gray'))
                if strcmp(LogLanguage, 'Russian')
                    error('Недопустимое значение Mapper.SymbolMapping');
                else
                    error('Invalid value Mapper.SymbolMapping');
                end
            end
        end

    % Вариант принятия решений о модуляционных символах:  Hard decision |
    % Log-likelihood ratio | Approximate log-likelihood ratio
        if ~isfield(Mapper, 'DecisionMethod')
            Mapper.DecisionMethod = 'Approximate log-likelihood ratio';
        else
            if ~(strcmp(Mapper.DecisionMethod, 'Hard decision') || ...
                    strcmp(Mapper.DecisionMethod, ...
                    'Log-likelihood ratio') || ...
                    strcmp(Mapper.DecisionMethod, ...
                    'Approximate log-likelihood ratio'))
                if strcmp(LogLanguage, 'Russian')
                    error('Недопустимое значение Mapper.DecisionMethod');
                else
                    error('Invalid value Mapper.DecisionMethod');
                end
            end
        end
end
function Sig = SetParamsSig(inSig, ParamsNumber, ...
    LogLanguage) %#ok<INUSD,DEFNU>

    % Пересохраним входные данные
        Sig = inSig;

    % Нужно ли выполнять формирование сигнала и выполнять его обработку
    % при приёме
        if ~isfield(Sig, 'isTransparent')
            Sig.isTransparent = true;
        else
            % Проверка корректности введённых значений
        end
end
function Channel = SetParamsChannel(inChannel, ParamsNumber, ...
    LogLanguage) %#ok<INUSD,DEFNU>

    % Пересохраним входные данные
        Channel = inChannel;

    % Нужно ли пропускать сигнал через канал
        if ~isfield(Channel, 'isTransparent')
            Channel.isTransparent = true;
        else
            % Проверка корректности введённых значений
        end
        
    % Тип канала: AWGN | Fading
        if ~isfield(Channel, 'Type')
            Channel.Type = 'AWGN';
        else
            % Проверка корректности введённых значений
        end
        
    % Тип многолучевого канала: '' | 'EPA' | 'EVA' | 'ETU'
    % Учитывается только при Channel.Type = 'Fading'.
        if ~isfield(Channel, 'FadingType')
            Channel.FadingType = '';
        else
            % Проверка корректности введённых значений
        end
end
function BER = SetParamsBER(inBER, ParamsNumber, ...
    LogLanguage) %#ok<INUSD,DEFNU>

    % Расчёт текущей точки останавливается, если
    %   ) превышена сложность или
    %   ) набрана достаточная статистика и количество переданных кадров
    %     больше либо равно, чем MinNumTrFrames
    %
    % Основной расчёт кривой помехоустойчивости останавливается, если
    %   ) превышена сложность или
    %   ) превышено ограничение максимального значения h2
    %
    % Сложность превышена, если передано бит больше, чем MaxNumTrBits, или
    %   передано кадров больше, чем MaxNumTrFrames.
    %
    % Целевые вероятности ошибок достигнуты, если оценка вероятности
    %   битовой ошибки меньше либо равна, чем MinBER, и оценка вероятности
    %   кадровой ошибки меньше либо равна, чем MinFER.
    %
    % Статистика считается достаточной, если количество битовых ошибок
    %   больше либо равно, чем MinNumErBits, и количество кадровых ошибок
    %   больше либо равно, чем MinNumErFrames.
    %
    % Дополнительный расчёт точек кривой помехоустойчивости ведётся до тех
    %   пор, пока для всех соседних точек кривой помехоустойчивости не
    %   будет верно, что
    %   ) отношение вероятностей битовой ошибки между соседними точками
    %     меньше либо равно, чем MaxBERRate, или
    %   ) разница h2 между этими точками меньше либо равна h2dBMinStep.
    
    % Пересохраним входные данные
        BER = inBER;

    % Количество учитываемых знаков после запятой при расчётах и выводе в
    % лог значений, связанных с h2
        if ~isfield(BER, 'h2Precision')
            BER.h2Precision = 2;
        else
            % Проверка корректности введённых значений
        end

    % Количество знаков после запятой для значения BER, указываемых в логе    
        if ~isfield(BER, 'BERPrecision')
            BER.BERPrecision = 8;
        else
            % Проверка корректности введённых значений
        end
        
    % Количество символов, используемых для отображения числа переданных и
    % числа ошибочных бит в логе
        if ~isfield(BER, 'BERNumRateDigits')
            BER.BERNumRateDigits = 10;
        else
            % Проверка корректности введённых значений
        end
        
    % Количество символов, используемых для отображения числа переданных и
    % числа ошибочных кадров в логе
        if ~isfield(BER, 'FERNumRateDigits')
            BER.FERNumRateDigits = 7;
        else
            % Проверка корректности введённых значений
        end

    % Минимальное количество моделируемых для каждой точки кривой
    % помехоустойчивости кадров (это ограничение снизу необходимо для
    % корректного моделирования в условиях многолучёвости)
        if ~isfield(BER, 'MinNumTrFrames')
            BER.MinNumTrFrames = 100;
        else
            % Проверка корректности введённых значений
        end

    % Значение h2 (дБ) первой точки при расчёте помехоустойчивости
        if ~isfield(BER, 'h2dBInit')
            BER.h2dBInit = 8.4;
        else
            % Проверка корректности введённых значений
        end

    % Начальное значение шага (дБ) для перехода к новым точкам при расчёте
    % помехоустойчивости
        if ~isfield(BER, 'h2dBInitStep')
            BER.h2dBInitStep = 0.4;
        else
            % Проверка корректности введённых значений
        end

    % Максимальное значение шага (дБ) для перехода к новым точкам при
    % расчёте кривой помехоустойчивости
        if ~isfield(BER, 'h2dBMaxStep')
            BER.h2dBMaxStep = 1.6;
        else
            % Проверка корректности введённых значений
        end

    % Минимальное значение шага (дБ)
        if ~isfield(BER, 'h2dBMinStep')
            BER.h2dBMinStep = 0.1;
        else
            % Проверка корректности введённых значений
        end

    % Максимальное значение рассматриваемого отношения сигнал/шум (если
    % кривая помехоустойчивости выйдет на насыщение со значением BER больше
    % требуемого, то это ограничение позволит прервать бесполезные
    % вычисления)
        if ~isfield(BER, 'h2dBMax')
            BER.h2dBMax = 25;
        else
            % Проверка корректности введённых значений
        end

    % Требуемое минимальное значение BER, по достижении которого вычисления
    % будут остановлены (если, конечно, ограничение по сложности
    % (BER.MaxNumTrBits) или иное ограничение не наступит раньше)
        if ~isfield(BER, 'MinBER')
            BER.MinBER = 10^-4;
        else
            % Проверка корректности введённых значений
        end

    % Минимальное количество ошибочных бит в каждой точке
        if ~isfield(BER, 'MinNumErBits')
            BER.MinNumErBits = 5*10^2;
        else
            % Проверка корректности введённых значений
        end

    % Требуемое минимальное значение FER, по достижении которого вычисления
    % будут остановлены
        if ~isfield(BER, 'MinFER')
            BER.MinFER = 1; % т.е. ограничения на это значение нет!
        else
            % Проверка корректности введённых значений
        end

    % Минимальное количество ошибочных кадров в каждой точке
        if ~isfield(BER, 'MinNumErFrames')
            BER.MinNumErFrames = 10^2;
        else
            % Проверка корректности введённых значений
        end

    % Максимальное количество переданных бит
        if ~isfield(BER, 'MaxNumTrBits')
            BER.MaxNumTrBits = 10^8;
        else
            % Проверка корректности введённых значений
        end

    % Максимальное количество переданных кадров
        if ~isfield(BER, 'MaxNumTrFrames')
            BER.MaxNumTrFrames = inf; % т.е. ограничения на это значение
                % нет!
        else
            % Проверка корректности введённых значений
        end

    % Максимальное отношение вероятностей битовых ошибок в соседних
    % точках, больше которого происходит уменьшение шага h2dB. Понятно, что
    % если идёт построение "нормальной" кривой помехоустойчивости, то
    % скорость спада значений вероятности ошибки тем больше, чем больше
    % значение h2 (дБ). При этом всегда важно отлавливать именно
    % изменения значения вероятности ошибки. Поэтому, если для
    % предыдущей пары отношение вероятностей ошибок было большое, то
    % для следующей пары оно будет ещё больше и, чтобы точнее
    % просчитать кривую помехоустойчивости (плюс, не уйти в ограничение по
    % сложности!), надо уменьшить шаг по оси h2 (дБ).
        if ~isfield(BER, 'MaxBERRate')
            BER.MaxBERRate = 5;
        else
            % Проверка корректности введённых значений
        end

    % Минимальное отношение вероятностей битовых ошибок в соседних
    % точках, меньше которого происходит увеличение шага h2dB. Возможна и
    % обратная ситуация, когда начало расчётов попадает на пологую
    % часть кривой помехоустойчивости. В такой ситуации можно смело
    % увеличивать шаг по оси h2 (дБ), не боясь потерять информацию об
    % изменении вероятности ошибки.
        if ~isfield(BER, 'MinBERRate')
            BER.MinBERRate = 2;
        else
            % Проверка корректности введённых значений
        end
end
function Common = SetParamsCommon(inCommon, ParamsNumber, ...
    LogLanguage) %#ok<INUSD,DEFNU>

    % Пересохраним входные данные
        Common = inCommon;

    % Имя файла для сохранения результатов
        if ~isfield(Common, 'SaveFileName')
            Common.SaveFileName = sprintf('Results%02d', ParamsNumber);
        else
            % Проверка корректности введённых значений
        end

    % Имя директории для сохранения результатов
        if ~isfield(Common, 'SaveDirName')
            Common.SaveDirName = 'Results';
        else
            % Проверка корректности введённых значений
        end

    % Количество кадров, генерируемых и обрабатываемых за одну итерацию.
    % При использовании Common.NumWorkers > 1 разумно, чтобы
    % NumOneIterFrames делилось на Common.NumWorkers без остатка.
        if ~isfield(Common, 'NumOneIterFrames')
            Common.NumOneIterFrames = 100;
        else
            % Проверка корректности введённых значений
        end

    % Количество ядер, используемых для параллельных вычислений
        if ~isfield(Common, 'NumWorkers')
            Common.NumWorkers = 1;
        else
            % Проверка корректности введённых значений
        end

    % Нужно ли делать обновления лога command window для каждой новой
    % порции расчитанных NumOneIterFrames кадров
        if ~isfield(Common, 'isRealTimeLogCWin')
            Common.isRealTimeLogCWin = 1;
        else
            % Проверка корректности введённых значений
        end

    % Нужно ли делать обновления лога в файле для каждой новой
    % порции расчитанных NumOneIterFrames кадров
        if ~isfield(Common, 'isRealTimeLogFile')
            Common.isRealTimeLogFile = 0;
        else
            % Проверка корректности введённых значений
        end
end