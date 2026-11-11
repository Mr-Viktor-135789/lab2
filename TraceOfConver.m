classdef TraceOfConver < handle
    properties (SetAccess = private)
        Level double = 0
        StepN double = 0
    end
    methods
        function obj = TraceOfConver(level)
            if nargin >= 1, obj.Level = max(0,min(2,round(level))); end
        end

        function log(obj, varargin)
            if obj.Level < 1, return; end
            obj.StepN = obj.StepN + 1;
            disp(sprintf('  [%2d] %s', obj.StepN, sprintf(varargin{:})));
        end

        function table(obj, title, hdr, data)
            if obj.Level < 2, return; end
            obj.log('%s', title);
            disp(['        ' strjoin(hdr,'  ')]);
            for r = 1:size(data,1)
                disp(['        ' strjoin(cellfun(@(x) num2str(x), data(r,:), 'Uni', 0), '  ')]);
            end
        end

        function crcTrace(obj, u, K)
            if obj.Level < 2, return; end
            r = zeros(1,8); d = cell(K,4);
            for k = 1:K
                f = xor(u(k), r(8));
                r = [f, r(1), xor(r(2),f), r(3), ...
                     xor(r(4),f), r(5), xor(r(6),f), xor(r(7),f)];
                d(k,:) = {k, u(k), f, num2str(r)};
            end
            obj.table('CRC-8', {'k','u','f','r1..r8'}, d);
        end

        function scramblerTrace(obj, payload, rot, K)
            if obj.Level < 2, return; end
            K = min(K, numel(payload));
            d = cell(K,4);
            for i = 1:K
                z = rot(i);
                d(i,:) = {i, ...
                    sprintf('%.3f%+.3fj', real(payload(i)), imag(payload(i))), ...
                    sprintf('%.3f%+.3fj', real(z), imag(z)), ...
                    sprintf('%.3f%+.3fj', real(payload(i)*z), imag(payload(i)*z))};
            end
            obj.table('PL scrambling  out = in * (C_I + jC_Q)', ...
                {'i','     in           ','C','            out'}, d);
        end

        function headerTrace(obj, name, varargin)
            if obj.Level < 1, return; end
            if isempty(varargin)
                disp(['===== ' name ' =====']);
            else
                disp(['===== ' name ' (' sprintf(varargin{:}) ') =====']);
            end
        end

        function checkTrace(obj, name, ok)
            if obj.Level < 1, return; end
            if ok, s = 'OK'; else, s = 'FAIL'; end
            fprintf('  %-22s : %s\n', name, s);
        end

        function matrixTrace(obj, name, rows)
            if obj.Level < 2, return; end
            for i = 1:size(rows,1)
                fprintf('  %s : %s\n', name(i), num2str(rows(i,:)));
            end
        end

       function ldpcColumnDivisionTrace(obj, NB, Q, M, ct1, ct2, u)
            if obj.Level < 1, return; end
            fprintf('===== LDPC: деление в столбик (GF(2)) =====\nNB=%d Q=%d M=%d | u(%d) = %s\n', ...
                NB, Q, M, numel(u), num2str(u));
            acc = zeros(1,M); rowId = 0; SHOW = 1;
            for t = {ct1, ct2}
                T = t{1};
                for g = 1:size(T,1)
                    a = T(g,2:end); grp = u(rowId*NB+1 : rowId*NB+NB);
                    fprintf('\nстрока %d: делимое=%s a=%s acc=%s\n', ...
                        rowId, num2str(grp), num2str(a), num2str(acc));
                    nOnes = sum(grp); cnt = 0;
                    for i = 0:NB-1
                        if grp(i+1)
                            cnt = cnt + 1;
                            pos = mod(a + i*Q, M) + 1;
                            before = acc; acc(pos) = xor(acc(pos),1);
                            mask = zeros(1,M); mask(pos) = 1;
                            if nOnes > SHOW+1 && cnt == SHOW+1
                                fprintf('  ...\n');
                            else
                                fprintf('  u[%d]=1 shift=%d pos=%s: %s XOR %s = %s\n', ...
                                    i, i*Q, num2str(pos), num2str(before), num2str(mask), num2str(acc));
                            end
                        end
                    end
                    fprintf('  acc = %s\n', num2str(acc));
                    rowId = rowId + 1;
                end
            end
            p = zeros(1,M); p(1) = acc(1);
            fprintf('\np(1)=%d\n', acc(1));
            for i = 2:M
                p(i) = xor(acc(i), p(i-1));
                fprintf('p(%d)=%d XOR %d=%d\n', i, acc(i), p(i-1), p(i));
            end
            fprintf('\nанализ\nacc = %s\np   = %s\n[u p] (%d бит) = %s\n', ...
                num2str(acc), num2str(p), numel(u)+numel(p), num2str([u p]));
        end
    end
end