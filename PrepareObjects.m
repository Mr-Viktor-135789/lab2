function [Objs, Ruler] = PrepareObjects(Params, ParamsNum, NumParams, ...
    LogLanguage)
% 
% Функция инициализации объектов

    % Инициализация cell-массива для хранения объектов главного цилка
        Objs = cell(Params.Common.NumWorkers, 1);
        
    % Цикл инициализации объектов главного цикла
        for k = 1:Params.Common.NumWorkers
            Objs{k}.Source = ClassSource(Params, LogLanguage);
            Objs{k}.Encoder = ClassEncoder(Params, LogLanguage);
            Objs{k}.Interleaver = ClassInterleaver(Params, LogLanguage);
            Objs{k}.Mapper = ClassMapper(Params, LogLanguage);
            Objs{k}.Sig = ClassSig(Params, LogLanguage);
            Objs{k}.Channel = ClassChannel(Params, Objs{k}, LogLanguage);
            Objs{k}.Stat = ClassStat(LogLanguage);
        end
    
    % Инициализация Ruler
        Ruler = ClassBERRuler(Params, ParamsNum, NumParams, LogLanguage);