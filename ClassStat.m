classdef ClassStat < handle
    properties (SetAccess = private)
        % ѕараметры, используемые дл€ накоплени€ статистики
            NumTrBits;   % количество переданных бит
            NumTrFrames; % количество переданных кадров
            NumErBits;   % количество ошибочных  бит
            NumErFrames; % количество ошибочных  кадров
        % ѕеременна€ управлени€ €зыком вывода информации дл€ пользовател€
            LogLanguage;
    end
    methods
        function obj = ClassStat(LogLanguage) %  онструктор
            % »нициализаци€ значений переменных статистики
                obj.NumTrBits   = 0;
                obj.NumTrFrames = 0;
                obj.NumErBits   = 0;
                obj.NumErFrames = 0;
            % ѕеременна€ LogLanguage
                obj.LogLanguage = LogLanguage;
        end
        function Step(obj, Frame)
            % ќбновление статистики
                obj.NumTrBits   = obj.NumTrBits   + ...
                    length(Frame.TxData);
                obj.NumTrFrames = obj.NumTrFrames + 1;
                Buf = sum(Frame.TxData ~= Frame.RxData);
                obj.NumErBits   = obj.NumErBits   + Buf;
                obj.NumErFrames = obj.NumErFrames + sign(Buf);
        end
        function Reset(obj)
            obj.NumTrBits   = 0;
            obj.NumTrFrames = 0;
            obj.NumErBits   = 0;
            obj.NumErFrames = 0;
        end            
    end
end