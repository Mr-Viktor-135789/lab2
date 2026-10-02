function Main(FirstParamsNum, Step4ParamsNum, LogLanguage)
%
% Главный запускаемый файл модели
%   Входных переменных может быть 0, 1, 2 или 3. Значения по умолчанию:
%       FirstParamsNum = 1;
%       Step4ParamsNum = 1;
%       LogLanguage = 'Russian'.
%
% Входные переменные:
%   Если имеется только одна входная переменная, то FirstParamsNum - массив
%       значений номеров наборов параметров, для которых нужно выполнить
%       моделирование.
%   Если входных переменных две или три, то FirstParamsNum, Step4ParamsNum
%       - номер первого набора параметров и шаг для перехода к последующему
%       набору параметров. Пара этих переменных предназначена, прежде
%       всего, для запуска модели на нескольких узлах.
%   LogLanguage - язык для вывода сообщений пользователю и сохранения лога
%       ('Russian' (по умолчанию) | 'English').

    % Очистка command window, закрытие всего
        clc;
        close all;

    % Проверим количество входных переменных
        if ~(nargin >= 0 && nargin <= 3)
            error(['Количество входных переменных Main должно быть ', ...
                '0, 1, 2 или 3. The number of input arguments to the ', ...
                'Main should be equal to 0, 1, 2 or 3.']);
        end
        
    % Определим язык для лога
        if nargin >= 0 && nargin <= 2
            LogLanguage = 'Russian';
        else
            if ~(strcmp(LogLanguage, 'Russian') || ...
                    strcmp(LogLanguage, 'English'))
                error(['Недопустимое значение переменной ', ...
                    'LogLanguage! Допустимые значения ''Russian'' и ', ...
                    '''English''. Invalid value of LogLanguage! ', ...
                    'Valid values are ''Russian'' and ''English''.']);
            end
        end            

    % Определим значения FirstParamsNum, Step4ParamsNum   
        if nargin == 0
            FirstParamsNum = 1;
            Step4ParamsNum = 1;
        elseif nargin == 1
            Step4ParamsNum = 1;
        else
            % Проверка корректности введённых значений
        end
        
    % Считывание параметров, значения которых отличаются от значений по
    % умолчанию
        Params = ReadSetup(LogLanguage);

    % Определим массив значений kVals - номеров параметров, для которых
    % должен быть выполнен расчёт (на данном узле)
        % Общее количество наборов параметров
            NumParams = length(Params);
        if nargin == 1
            kVals = FirstParamsNum;
        else
            kVals = FirstParamsNum : Step4ParamsNum : NumParams;
        end

    % Проверка значений kVals
        if (min(kVals) < 1) || (max(NumParams) > NumParams)
            if strcmp(LogLanguage, 'Russian')
                error('Недопустимое значение номера набора парметров');
            else
                error('Invalid value of number for parameters set');
            end
        end
        
    % Цикл по набору параметров
        for k = kVals
            % Установка значений параметров по умолчанию
                Params{k} = SetParams(Params{k}, k, LogLanguage);

            % Вычисление/проверка параметров
                Params{k} = CalcAndCheckParams(Params{k}, LogLanguage);

            % Инициализация объектов
                [Objs, Ruler] = PrepareObjects(Params{k}, k, ...
                    NumParams, LogLanguage);

            % Переход в режим параллельных вычислений (при необходимости)
                Ruler.StartParallel();

            % Сброс генераторов случайных чисел в начальное состояние
                Ruler.ResetRandStreams();
                
            % Цикл для одного набора параметров
                while ~Ruler.isStop
                    % Обработка очередного блока кадров
                        if Ruler.NumWorkers > 1
                            parfor n = 1:Ruler.NumWorkers
                                Objs{n} = LoopFun(Objs{n}, Ruler, n);
                            end
                        else
                            Objs{1} = LoopFun(Objs{1}, Ruler, 1);
                        end
                    % Обработка результатов
                        isPointFinished = Ruler.Step(Objs);
                        
                    % Сохранение результатов при окончании расчёта
                    % очередной точки
                        if isPointFinished
                            Ruler.Saves(Objs, Params{k});
                        end
                end

            % Выход из параллельных вычислений (при необходимости)
                if isequal(k, kVals(end))
                    Ruler.StopParallel();
                end

            % Удаление всех объектов
                DeleteObjects(Objs, Ruler);
        end

end
function Objs = LoopFun(inObjs, Ruler, WorkerNum)
% Цикл для одного набора параметров

    % Хотя все объекты в модели типа handle, т.е. фактически это указатели,
    % тем не менее, для корректной работы parfor нужо делать явное
    % переприсвоение результатов на выход (https://www.mathworks.com/help/
    % distcomp/objects-and-handles-in-parfor-loops.html)
        Objs = inObjs;

    % Цикл по количеству кадров
        for k = 1:Ruler.OneWorkerNumOneIterFrames(WorkerNum)
            % Передатчик
                % Генерирование полезных данных
                    Frame.TxData       = Objs.Source.Step();
                % Кодирование кодом, исправляющим ошибки
                    Frame.TxEncData    = Objs.Encoder.StepTx(Frame.TxData);
                % Перемешивание полезных данных
                    Frame.TxIntData    = Objs.Interleaver.StepTx( ...
                        Frame.TxEncData);
                % Отображение на модуляционные символы
                    Frame.TxModSymbols = Objs.Mapper.StepTx( ...
                        Frame.TxIntData);
                % Генерирование сигнала
                    Frame.TxSignal     = Objs.Sig.StepTx( ...
                        Frame.TxModSymbols);

            % Канал
                [Frame.RxSignal, InstChannelParams] = Objs.Channel.Step(...
                    Frame.TxSignal, Ruler.h2dB);

            % Приёмник
                % Обработка принятого сигнала - вычисление модуляционных
                % символов
                    Frame.RxModSymbols = Objs.Sig.StepRx(Frame.RxSignal);
                % Демодуляция
                    Frame.RxIntData    = Objs.Mapper.StepRx( ...
                        Frame.RxModSymbols, InstChannelParams);
                % Обратное перемешивание
                    Frame.RxEncData    = Objs.Interleaver.StepRx( ...
                        Frame.RxIntData);
                % Декодирование кодом, исправляющим ошибки
                    Frame.RxData       = Objs.Encoder.StepRx( ...
                        Frame.RxEncData);

            % Накопление статистики по текущему Frame
                Objs.Stat.Step(Frame);
        end
end