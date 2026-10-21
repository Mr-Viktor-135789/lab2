classdef TraceOfConver < handle
    properties (SetAccess = private)
        Level  double = 0
        StepN  double = 0
    end
    methods
        function obj = TraceOfConver(level)
            if nargin >= 1, obj.Level = max(0,min(2,round(level))); end
        end

        function log(obj, varargin)
            if obj.Level < 1, return; end
            obj.StepN = obj.StepN + 1;
            fprintf('[%3d] %s\n', obj.StepN, sprintf(varargin{:}));
        end

        function table(obj, title, hdr, data)
            if obj.Level < 2, return; end
            obj.log('%s', title);
            fprintf('     %s\n', strjoin(hdr,'  '));
            for r = 1:size(data,1)
                fprintf('     %s\n', ...
                    strjoin(cellfun(@(x) num2str(x), data(r,:), 'Uni', 0), '  '));
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
            obj.table('CRC-8 step-by-step', {'k','u','f','r1..r8'}, d);
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
            obj.table('PL complex multiplier  out = in * (C_I+jC_Q)', ...
                {'i','in','C','out'}, d);
        end
    end
end