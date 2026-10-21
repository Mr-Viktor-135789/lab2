classdef ClassEncoder < handle
    properties
        Mode = 'BCH+LDPC';
    end

    properties
        BCH_cwLen = 64800;
        BCH_k     = 53808;   
    end

    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        Date;
        LDPCcfg;

        N = 64800;
        K = 54000;
        M = N - K;
        Q = 72;
        NB = 360;

        BCH_parityBits;

        ct1;
        ct2;
    end

    methods
        function obj = ClassEncoder(Params, LogLanguage)
            Encoder = Params.Encoder;
            obj.isTransparent = Encoder.isTransparent;
            obj.LogLanguage  = LogLanguage;
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
                    OutData = obj.encodeLDPC(bchOut);
            end
        end

%% BCH begin
        function OutData = encodeBCH(obj, InData)
            msg = double(InData(:));
            msg = [msg; zeros(obj.BCH_k - numel(msg), 1)];
            out = bchEncode(msg, obj.BCH_k, obj.BCH_cwLen);
            OutData = double(out(:).');
        end
%% BCH end

%% LDPC begin
        function OutData = encodeLDPC(obj, InData)
            u = mod(double(InData(:).'), 2);
            if numel(u) > obj.K
                error('Слишком много входных бит: %d > K=%d', numel(u), obj.K);
            end

            u = [u, zeros(1, obj.K - numel(u))];
            acc = zeros(1, obj.M);

            numRows1 = size(obj.ct1, 1);
            numRows2 = size(obj.ct2, 1);
            numRows  = numRows1 + numRows2;
            
            for g = 0:numRows-1
                if g < numRows1
                    addrs = obj.ct1(g+1, 2:end);
                else
                    addrs = obj.ct2(g - numRows1 + 1, 2:end);
                end
                base = g * obj.NB;
            
                for i = 0:obj.NB-1
                    if u(base + i + 1)
                        for a = addrs
                            pos = mod(a + i*obj.Q, obj.M) + 1;
                            acc(pos) = xor(acc(pos), 1);
                        end
                    end
                end
            end

            p = zeros(1, obj.M);
            p(1) = acc(1);
            for i = 2 : obj.M
                p(i) = xor(acc(i), p(i-1));
            end

            OutData = [u, p];
        end

        function loadLDPCtables(obj)
            obj.ct1 = DataForBchLdpc.LDPC_R56_CT1;
            obj.ct2 = DataForBchLdpc.LDPC_R56_CT2;
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