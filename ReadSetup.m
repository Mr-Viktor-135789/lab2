function Params = ReadSetup(LogLanguage)
%
% Функция выполняет поиск файлов, имя которых начинается с 'Setup' и имеет
% расширение 'm'. Файл должен содержать инициализацию параметров (без части
% 'Params.'). Файлы Setup должны быть написаны и будут обрабатываться по
% правилам m-языка. Разделителем разных наборов параметров является
% '% End of Params' (следовательно, например, всё, что написано в строке
% после '% End of Params' учитываться не будет, так как это комментарии).
% Конец файла по определению считается окончанием определения набора
% параметров, поэтому ставить '% End of Params' в конце файла не
% обязательно. Пустые наборы параметров отбрасываются. Параметры в разных
% файлах по определению считаются принадлежащими разным наборам. Если все
% файлы будут пустыми или файлов не будет вовсе, то будет выполнен один
% расчёт с пустым набором параметров, т.е. с параметрами по умолчанию.
% Подсказка: если требуется получить пустой набор параметров при условии,
% что в Setup есть не пустые наборы, то нужно сделать набор параметров, в
% котором указать одно из значений по умолчанию.
%
% Выходные параметры:
%   Params - cell-массив с частичными наборами параметров, установленных
%       согласно файлу(ам) Setup.

    % Инициализация результата
        Params = cell(0);

    % Учитываемые имена полей структуры Params верхнего уровня    
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
   
    % Поиск файлов
        % Инициализация массива имён файлов
            FileNames = cell(0);
        % Определим содержимое рабочей директории
            Listing = dir;
        % Цикл по количеству элементов, содержащихся в директории
            for k = 1:length(Listing)
                % Рассматриваем только файлы
                if ~Listing(k).isdir
                    % Проверим, чтобы имя файла начиналось на Setup и имело
                    % расширение 'm'
                    if length(Listing(k).name) >= length('Setup.m')
                        if strcmp(Listing(k).name(1:length('Setup')), ...
                                'Setup') && strcmp(Listing(k).name( ...
                                end-1:end), '.m')
                            FileNames{end+1} = Listing(k).name; %#ok<AGROW>
                        end
                    end
                end
            end

    % Обработка каждого найденного файла
        for k = 1:length(FileNames)
            % Сохраним текущее количество наборов параметров
                NumParams = length(Params);

            % Попробуем открыть файл с параметрами
                try
                    fid = fopen(FileNames{k});
                catch
                    if strcmp(LogLanguage, 'Russian')
                        error(['Не удалось открыть файл настройки ', ...
                            '%s!\n'], FileNames{k});
                    else
                        error('Failed to open setup file %s!\n', ...
                            FileNames{k});
                    end
                end
                
            % Инициализация очередного набора параметров
                BufParams = [];
                
            % Поочерёдное считывание строк из файла
                tline = fgetl(fid);
                isFindEndOfParams = false; % это присвоение необходимо на
                    % случай, если файл пустой
                while ischar(tline)
                    % Добавим 'BufParams.' перед именем полей верхнего
                    % уровня
                        for n = 1:length(FieldNames)
                            OldStr = [FieldNames{n}, '.'];
                            NewStr = ['BufParams.', OldStr];
                            tline = strrep(tline, OldStr, NewStr);
                        end

                    % Попробуем выполнить строку
                        try
                            eval(tline);
                        catch
                            if strcmp(LogLanguage, 'Russian')
                                error(['Не удалось выполнить ''%s'' ', ...
                                    'в файле %s!\n'], tline, FileNames{k});
                            else
                                error(['Failed to evaluate ''%s'' in ', ...
                                    'file %s!\n'], tline, FileNames{k});
                            end
                        end

                    % Определим, есть ли в этой строке флаг окончания
                    % набора параметров
                        isFindEndOfParams = contains(tline, ...
                            '% End of Params');
                    
                    % Если был найден флаг окончания набора параметров и
                    % текущий набор параметров не пустой, то нужно добавить
                    % текущий набор параметров в качестве нового набора и
                    % инициализировать накопление нового набора параметров
                        if isFindEndOfParams
                            if ~isempty(BufParams)
                                Params{end+1} = BufParams; %#ok<AGROW>
                                BufParams = [];
                            end
                        end
                    
                    % Считываем очередную строку файла
                        tline = fgetl(fid);
                end

            % Если файл закончился, и текущий набор параметров не пустой,
            % то надо добавить его в качестве нового набора параметров
                if ~isFindEndOfParams
                    if ~isempty(BufParams)
                        Params{end+1} = BufParams; %#ok<AGROW>
                    end
                end

            % Закроем файл
                fclose(fid);

            % Вывод результата на экран
                if strcmp(LogLanguage, 'Russian')
                    fprintf(['%s Из файла %s считано %d наборов ', ...
                        'параметров.\n'], datestr(now), FileNames{k}, ...
                        length(Params) - NumParams);
                else
                    fprintf(['%s %d parameter sets are parsed from ', ...
                        'file %s.\n'], datestr(now), length(Params) - ...
                        NumParams, FileNames{k});
                end
                fprintf('\n');
        end
        
    % Если не удалось собрать ни один набор параметров, то создадим пустой
    % для выполнения расчётов с параметрами по умолчанию
        if isempty(Params)
            Params = cell(1);
            % Вывод результата на экран
                if strcmp(LogLanguage, 'Russian')
                    fprintf(['%s Не найден ни один набор параметров, ', ...
                        'поэтому будет выполнен один расчёт с ', ...
                        'параметрами по умолчанию.\n'], datestr(now));
                else
                    fprintf(['%s No parameters were found thus one ', ...
                        'calculation with default parameters will be ', ...
                        'performed.\n'], datestr(now));
                end                    
                fprintf('\n');
        end