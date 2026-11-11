classdef ClassChannel < handle
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
    end
    properties (SetAccess = private)
        Ps;    % средн€€ мощность символа
        Pb;    % мощность на модул€ционный бит
        Pbd;   % мощность на информационный бит (с учЄтом скорости кода)
        Rate;  % скорость LDPC (5/6)
    end
    methods
        function obj = ClassChannel(Params, Objs, LogLanguage)
            Channel = Params.Channel;
            obj.isTransparent = Channel.isTransparent;
            obj.LogLanguage = LogLanguage;

            Const = Objs.Mapper.Constellation;
            obj.Ps = mean(abs(Const).^2);
            obj.Pb = obj.Ps / Objs.Mapper.log2M;

            % —корость кода: из Encoder или из Setup (5/6)
            if isfield(Params, 'Encoder') && isfield(Params.Encoder, 'CodeRate')
                r = Params.Encoder.CodeRate;
                if ischar(r)
                    parts = strsplit(r, '/');
                    obj.Rate = str2double(parts{1}) / str2double(parts{2});
                else
                    obj.Rate = r;
                end
            else
                obj.Rate = 5/6;
            end

            % Ёнерги€ на информационный бит: Es / (log2M * Rate)
            obj.Pbd = obj.Pb / obj.Rate;
        end

        function [OutData, InstChannelParams] = Step(obj, InData, h2dB)
        %STEP ƒобавл€ет комплексный јЅ√Ў.
        %   h2dB Ч отношение Eb/N0 по информационным битам (дЅ).
            if obj.isTransparent || isinf(h2dB)
                OutData = InData;
                InstChannelParams.Variance = 0;
                InstChannelParams.Sigma = 0;
                return
            end

            % ƒисперси€ комплексного шума: N0 = Pbd * 10^(-h2dB/10)
            N0 = obj.Pbd * 10^(-h2dB/10);
            Sigma = sqrt(N0 / 2);   % на каждую квадратуру
            InstChannelParams.Variance = N0;   % E|n|^2 = 2*Sigma^2 = N0
            InstChannelParams.Sigma = Sigma;

            Noise = Sigma * (randn(size(InData)) + 1i*randn(size(InData)));
            OutData = InData + Noise;
        end
    end
end