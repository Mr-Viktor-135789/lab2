classdef ClassEncoder < handle
    properties
        Mode = 'BCH+LDPC';
    end

        properties
        BCH_cwLen = 54000;
        BCH_k     = 53840;   
    end

    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        Date;
        LDPCcfg;

        N = 64800;
        K = 54000;
        M;
        Q;
        NB = 360;

        BCH_parityBits;

        ct1;
        ct2;
        TraceObj;
    end

    methods
        function obj = ClassEncoder(Params, LogLanguage)
            Encoder = Params.Encoder;
            obj.isTransparent = Encoder.isTransparent;
            obj.LogLanguage = LogLanguage;

            obj.M = obj.N-obj.K;         
            obj.Q = obj.M/obj.NB;  

            % --- Trace ---
            disp('===== FEC (BCH + LDPC) =====');
            if isfield(Params,'Common') && isfield(Params.Common,'Trace')
                obj.TraceObj = TraceOfConver(Params.Common.Trace);
            else
                obj.TraceObj = TraceOfConver(0);
            end
        end
        
       
        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end

            switch upper(obj.Mode)
                case 'BCH+LDPC'
                    if isempty(obj.ct1), obj.loadLDPCtables(); end
                    bchOut = obj.encodeBCH(InData);
                    assert(numel(bchOut) == obj.K, 'BCH+LDPC: выход BCH (%d) != K_LDPC (%d)', ...
                        numel(bchOut), obj.K);

                     % --- Trace ---
                     disp(sprintf('[  6] BCH : %6d -> %6d  (+%d проверочных, K=%d, N=%d, t=10)', ...
                            numel(InData), numel(bchOut), numel(bchOut)-numel(InData), ...
                            obj.BCH_k, obj.BCH_cwLen));

                    OutData = obj.encodeLDPC(bchOut);

                    disp(sprintf('[  7] LDPC: %6d -> %6d  (+%d проверочных, K=%d, N=%d, Q=%d)', ...
                            numel(bchOut), numel(OutData), numel(OutData)-numel(bchOut), ...
                            obj.K, obj.N, obj.Q));
                    disp(sprintf('       итог FEC: %d -> %d бит (rate = %.4f, ожидалось %.4f)', ...
                        numel(InData), numel(OutData), numel(InData)/numel(OutData), ...
                        obj.K/obj.N));
                end
            end
        
%% BCH begin
        function OutData = encodeBCH(obj, InData)
            msg = double(InData(:));
            n_full = 65535;
            k_full = n_full - (obj.BCH_cwLen - obj.BCH_k);   % 65375 дл€ R=5/6
            msg = [msg; zeros(k_full - numel(msg), 1)];
            code = bchenc(gf(msg.'), n_full, k_full);
            code = double(code.x(:));
            OutData = code(end - obj.BCH_cwLen + 1 : end).';  % укорачиваем до 54000
        end
%% BCH end

%% LDPC begin
        function OutData = encodeLDPC(obj, InData)

            persistent H A B
            if isempty(H)
                H = dvbs2ldpc(5/6);        % 10800 x 64800
                A = H(:, 1:54000);         % 10800 x 54000
                B = H(:, 54001:end);       % 10800 x 10800
            end
        
            u = mod(double(InData(:)), 2);
            if numel(u) > 54000
                error('—лишком много входных бит: %d > K=54000', numel(u));
            end
            u = [u; zeros(54000 - numel(u), 1)];

            acc = mod(A * u, 2);           % 10800 x 1
            
            p = zeros(10800, 1);
            p(1) = acc(1);
            for i = 2:10800
                p(i) = xor(acc(i), p(i-1));
            end
        
            OutData = [u; p].';
        end
        function loadLDPCtables(obj)
            S = load('LDPC_R56_CT.mat');
            obj.ct1 = S.ct1;
            obj.ct2 = S.ct2;
        end
%% LDPC end

        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            OutData = InData;
        end
    end
end