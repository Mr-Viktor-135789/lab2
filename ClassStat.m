classdef ClassStat < handle
    % Сбор статистики восстановления MPEG-TS.
    properties (SetAccess = private)
        NumTrBits;
        NumTrFrames;
        NumErBits;
        NumErFrames;
        NumTrPackets;
        NumErPackets;
        NumErBytes;
        LogLanguage;
    end
    methods
        function obj = ClassStat(LogLanguage)
            obj.LogLanguage = LogLanguage;
            obj.Reset();
        end
        function Step(obj, Frame)
            tx = uint8(Frame.TxData);
            rx = uint8(Frame.RxData);
            if ~isequal(size(tx), size(rx))
                error('Размеры переданных и восстановленных данных не совпадают.');
            end
            difference = bitxor(tx(:), rx(:));
            obj.NumTrBits = obj.NumTrBits + 8 * numel(tx);
            obj.NumTrFrames = obj.NumTrFrames + 1;
            obj.NumErBytes = obj.NumErBytes + sum(difference ~= 0);
            for k = 1:8
                obj.NumErBits = obj.NumErBits + sum(bitget(difference, k));
            end
            packetErrors = sum(any(tx ~= rx, 2));
            obj.NumTrPackets = obj.NumTrPackets + size(tx, 1);
            obj.NumErPackets = obj.NumErPackets + packetErrors;
            obj.NumErFrames = obj.NumErFrames + double(packetErrors > 0);
        end
        function Reset(obj)
            obj.NumTrBits = 0;
            obj.NumTrFrames = 0;
            obj.NumErBits = 0;
            obj.NumErFrames = 0;
            obj.NumTrPackets = 0;
            obj.NumErPackets = 0;
            obj.NumErBytes = 0;
        end
    end
end
