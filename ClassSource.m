classdef ClassSource < handle
    % Генератор тестовых пакетов MPEG-TS.
    properties (SetAccess = private)
        NumBitsPerFrame;
        NumTSPacketsPerFrame;
        LogLanguage;
    end
    methods
        function obj = ClassSource(Params, LogLanguage)
            obj.NumBitsPerFrame = Params.Source.NumBitsPerFrame;
            obj.NumTSPacketsPerFrame = Params.Source.NumTSPacketsPerFrame;
            obj.LogLanguage = LogLanguage;
        end
        function Packets = Step(obj)
            % Создаём корректную структуру TS-пакета: заголовок и 184 байта данных.
            Packets = zeros(obj.NumTSPacketsPerFrame, 188, 'uint8');
            for k = 1:obj.NumTSPacketsPerFrame
                Packets(k, 1:4) = uint8([hex2dec('47'), 1, 0, 16 + mod(k - 1, 16)]);
                Packets(k, 5:188) = uint8(randi([0, 255], 1, 184));
            end
        end
    end
end
