classdef ClassSig < handle
    % DVB-S2 physical-layer signal generator (ETSI EN 302 307-1, 5.4-5.6).
    %
    % Legacy use: ClassSig(Params, LogLanguage), StepTx(x), StepRx(x).
    %   Existing BER model is unaffected if Sig.Mode is absent / 'Legacy'.
    %
    % DVB-S2 use: provide Params.Sig.Mode='DVB-S2', isTransparent=false,
    %   Modulation, CodeRate, Rolloff, and optional parameters (see README).
    %   StepTx() accepts exactly 64800 (normal) or 16200 (short) FEC bits
    %   AFTER bit interleaving; StepTx([]) emits a dummy PLFRAME.
    %   Output is complex baseband samples by default.
    %
    % This is a TRANSMITTER component, NOT an FEC encoder or a receiver.
    % In DVB-S2 mode, StepRx raises an error rather than silently passing
    % data through an unimplemented demodulator.

    properties (SetAccess = private)
        isTransparent
        LogLanguage
        Mode
        Modulation
        CodeRate
        FrameLength
        Pilots
        Rolloff
        Span
        SamplesPerSymbol
        SymbolRate
        CarrierFrequency
        OutputFormat
        InputFormat
        ScramblingCode
        Modcod
        BitsPerSymbol
    end

    properties (Access = private)
        Constellation
        ScramblingRotations
        FilterTaps
        TraceObj 
    end

    methods
        function obj = ClassSig(Params, LogLanguage)
            if nargin < 2 || isempty(LogLanguage)
                LogLanguage = 'English';
            end
            if nargin < 1 || ~isstruct(Params) || ~isfield(Params, 'Sig')
                error('ClassSig:Config', 'Provide Params.Sig structure.');
            end
            sig = Params.Sig;
            obj.LogLanguage = LogLanguage;
            obj.Mode = ClassSig.fieldOr(sig, 'Mode', 'Legacy');
            obj.isTransparent = ClassSig.fieldOr(sig, 'isTransparent', true);
            if strcmpi(obj.Mode, 'Legacy')
                % Backwards compatible with the original repository.
                return;
            end
            if ~strcmpi(obj.Mode, 'DVB-S2')
                error('ClassSig:Config', 'Sig.Mode must be Legacy or DVB-S2.');
            end
            if obj.isTransparent
                error('ClassSig:Config', ...
                    'Set Sig.isTransparent=false to enable DVB-S2 processing.');
            end
            required = {'Modulation', 'CodeRate', 'Rolloff'};
            for ii = 1:numel(required)
                if ~isfield(sig, required{ii})
                    error('ClassSig:Config', 'Missing Sig.%s.', required{ii});
                end
            end
            obj.Modulation = upper(char(sig.Modulation));
            obj.CodeRate = char(sig.CodeRate);
            obj.FrameLength = ClassSig.fieldOr(sig, 'FrameLength', 64800);
            obj.Pilots = ClassSig.fieldOr(sig, 'Pilots', true);
            obj.Rolloff = sig.Rolloff;
            obj.Span = ClassSig.fieldOr(sig, 'Span', 10);
            obj.SamplesPerSymbol = ClassSig.fieldOr(sig, 'SamplesPerSymbol', 4);
            obj.SymbolRate = ClassSig.fieldOr(sig, 'SymbolRate', 1e6);
            obj.CarrierFrequency = ClassSig.fieldOr(sig, 'CarrierFrequency', 0);
            obj.OutputFormat = lower(char(ClassSig.fieldOr(sig, 'OutputFormat', 'baseband')));
            obj.InputFormat = lower(char(ClassSig.fieldOr(sig, 'InputFormat', 'bits')));
            obj.ScramblingCode = ClassSig.fieldOr(sig, 'ScramblingCode', 0);

            validModulations = {'QPSK','8PSK','16APSK','32APSK'};
            if ~any(strcmp(obj.Modulation, validModulations))
                error('ClassSig:Config', 'Unsupported DVB-S2 modulation.');
            end
            switch obj.Modulation
                case 'QPSK',   obj.BitsPerSymbol = 2;
                case '8PSK',   obj.BitsPerSymbol = 3;
                case '16APSK', obj.BitsPerSymbol = 4;
                case '32APSK', obj.BitsPerSymbol = 5;
            end
            if ~ismember(obj.FrameLength, [64800 16200])
                error('ClassSig:Config', 'FrameLength must be 64800 or 16200.');
            end
            if ~(isscalar(obj.Pilots) && (isequal(obj.Pilots, true) || isequal(obj.Pilots, false)))
                error('ClassSig:Config', 'Pilots must be true or false.');
            end
            if ~any(abs(obj.Rolloff - [0.20 0.25 0.35]) < 1e-10)
                error('ClassSig:Config', 'Rolloff must be .20, .25 or .35.');
            end
            if ~(isscalar(obj.SamplesPerSymbol) && obj.SamplesPerSymbol >= 2 && ...
                    obj.SamplesPerSymbol == floor(obj.SamplesPerSymbol))
                error('ClassSig:Config', 'SamplesPerSymbol must be integer >=2.');
            end
            if ~(isscalar(obj.Span) && obj.Span > 0 && obj.Span == floor(obj.Span) && ...
                    mod(obj.Span * obj.SamplesPerSymbol, 2) == 0)
                error('ClassSig:Config', 'Span*samplesPerSymbol must be even.');
            end
            if ~(isscalar(obj.SymbolRate) && isfinite(obj.SymbolRate) && obj.SymbolRate > 0)
                error('ClassSig:Config', 'SymbolRate must be positive and finite.');
            end
            if ~(isscalar(obj.ScramblingCode) && obj.ScramblingCode == floor(obj.ScramblingCode) ...
                    && obj.ScramblingCode >= 0 && obj.ScramblingCode <= 262141)
                error('ClassSig:Config', 'ScramblingCode outside [0, 262141].');
            end
            if ~any(strcmp(obj.OutputFormat, {'baseband','rf'}))
                error('ClassSig:Config', 'OutputFormat must be baseband or rf.');
            end
            if ~any(strcmp(obj.InputFormat, {'bits','symbols'}))
                error('ClassSig:Config', 'InputFormat must be bits or symbols.');
            end
            if strcmp(obj.OutputFormat, 'rf')
                sampleRate = obj.SymbolRate * obj.SamplesPerSymbol;
                if ~(isscalar(obj.CarrierFrequency) && isfinite(obj.CarrierFrequency) && ...
                        obj.CarrierFrequency > 0 && obj.CarrierFrequency < sampleRate/2)
                    error('ClassSig:Config', 'RF carrier must satisfy 0 < fc < fs/2.');
                end
            end

            obj.Modcod = ClassSig.findModcod(obj.Modulation, obj.CodeRate);
            obj.Constellation = ClassSig.makeConstellation(obj.Modulation, obj.CodeRate);
            obj.FilterTaps = ClassSig.makeRrc(obj.Rolloff, obj.Span, obj.SamplesPerSymbol);
            obj.ScramblingRotations = ClassSig.makeGoldRotations(obj.ScramblingCode);
            % --- Trace ---
            if isfield(Params,'Common') && isstruct(Params.Common) ...
                    && isfield(Params.Common,'Trace')
                obj.TraceObj = TraceOfConver(Params.Common.Trace);
            else
                obj.TraceObj = TraceOfConver(0);
            end
        end

        function [OutData, info] = StepTx(obj, InData)
            if obj.isTransparent || strcmpi(obj.Mode, 'Legacy')
                OutData = InData;
                info = struct('Mode','Legacy','IsDummy',false);
                return;
            end
            if nargin < 2
                error('ClassSig:Input', 'Supply FECFRAME bits/symbols or [].');
            end
            dummy = isempty(InData);
            if dummy
                modSymbols = [];
            elseif strcmp(obj.InputFormat, 'bits')
                modSymbols = obj.MapBits(InData);
            else
                if ~isnumeric(InData) || ~isvector(InData) || ...
                        numel(InData) ~= obj.FrameLength / obj.BitsPerSymbol || ...
                        any(~isfinite(InData(:)))
                    error('ClassSig:Input', 'Expected one XFECFRAME of complex symbols.');
                end
                modSymbols = InData(:);
            end
            [plsymbols, info] = obj.MakePLFrame(modSymbols);
            info.PLSymbols = plsymbols;
            info.RRCTaps = obj.FilterTaps;
            info.GroupDelaySamples = (numel(obj.FilterTaps)-1)/2;
            info.SampleRate = obj.SymbolRate * obj.SamplesPerSymbol;
            OutData = obj.PulseShape(plsymbols);
            if strcmp(obj.OutputFormat, 'rf')
                t = (0:numel(OutData)-1).' / info.SampleRate;
                OutData = real(OutData .* exp(1i*2*pi*obj.CarrierFrequency*t));
            end
            info.IsDummy = dummy;
        end

        function OutData = StepRx(obj, InData)
            if obj.isTransparent || strcmpi(obj.Mode, 'Legacy')
                OutData = InData;
                return;
            end
            error('ClassSig:ReceiverNotImplemented', ...
                ['ClassSig implements DVB-S2 transmitter only. ', ...
                 'A receiver needs synchronization, matched filtering, ', ...
                 'PL descrambling, demapping and FEC decoding.']);
        end

        function symbols = MapBits(obj, bits)
            obj.requireDvb();
            if ~(isnumeric(bits) || islogical(bits)) || ~isvector(bits) || ...
                    numel(bits) ~= obj.FrameLength || any(~(bits(:)==0 | bits(:)==1))
                error('ClassSig:Input', 'Expected exactly FrameLength binary FEC bits.');
            end
            groups = reshape(double(bits(:)), obj.BitsPerSymbol, []).';
            weights = 2.^(obj.BitsPerSymbol-1:-1:0).';
            index = groups * weights + 1;
            symbols = obj.Constellation(index);
            symbols = symbols(:);
        end

        function [frame, info] = MakePLFrame(obj, symbols)
            obj.requireDvb();
            dummy = isempty(symbols);
            if dummy
                modcod = 0;
                frameSizeBit = 0;
                pilotBit = 0;
                nSlots = 36;
                pilotCount = 0;
                payload = repmat((1+1i)/sqrt(2), 36*90, 1);
                pilotPositions = zeros(0,1);
            else
                if ~isnumeric(symbols) || ~isvector(symbols) || ...
                        numel(symbols) ~= obj.FrameLength/obj.BitsPerSymbol || ...
                        any(~isfinite(symbols(:)))
                    error('ClassSig:Input', 'Expected one mapped XFECFRAME.');
                end
                modcod = obj.Modcod;
                frameSizeBit = double(obj.FrameLength == 16200);
                pilotBit = double(obj.Pilots);
                nSlots = numel(symbols)/90;
                if nSlots ~= floor(nSlots)
                    error('ClassSig:Internal', 'XFECFRAME is not an integer number of slots.');
                end
                pilotCount = double(obj.Pilots) * floor((nSlots-1)/16);
                payload = complex(zeros(numel(symbols)+pilotCount*36,1));
                pilotPositions = zeros(pilotCount*36,1);
                inOffset = 0;
                outOffset = 0;
                nextPilot = 1;
                pilotSymbol = (1+1i)/sqrt(2);
                for k = 1:nSlots
                    payload(outOffset+(1:90)) = symbols(inOffset+(1:90));
                    outOffset = outOffset + 90;
                    inOffset = inOffset + 90;
                    if obj.Pilots && mod(k,16)==0 && k<nSlots
                        ids = outOffset+(1:36);
                        payload(ids) = pilotSymbol;
                        pilotPositions(nextPilot:nextPilot+35) = ids + 90;
                        nextPilot = nextPilot + 36;
                        outOffset = outOffset + 36;
                    end
                end
            end
            header = obj.MakePLHeader(modcod, frameSizeBit, pilotBit);
            

            
            rotations = obj.ScramblingRotations(1:numel(payload));
            payload = payload .* rotations;

            % --- Trace ---
            if ~isempty(obj.TraceObj) && obj.TraceObj.Level >= 2
                obj.TraceObj.scramblerTrace(payload(1:8), rotations(1:8), 8);
                okPow = abs(mean(abs(payload(1:8)).^2) - mean(abs((payload(1:8)./rotations(1:8))).^2)) < 1e-9;
                obj.TraceObj.checkTrace('|C| = 1', all(abs(rotations(1:8))==1));
            end

            frame = [header; payload];
            if ~isempty(obj.TraceObj) && obj.TraceObj.Level >= 1
                fprintf('[  9] PLFRAME: %d символов\n', numel(frame));
                fprintf('       PLHEADER : 90   (SOF=26, PLS=64)\n');
                fprintf('       XFECFRAME: %d   (%d слотов × 90)\n', numel(symbols), nSlots);
                fprintf('       пилоты   : %d блоков × 36 = %d символов\n', ...
                    pilotCount, pilotCount*36);
                fprintf('       MODCOD   : %d\n', modcod);
                obj.TraceObj.checkTrace(sprintf('90 + %d + %d = %d', ...
                    numel(symbols), pilotCount*36, numel(frame)), ...
                    90 + numel(symbols) + pilotCount*36 == numel(frame));
            end
            info = struct();
            info.Modcod = modcod;
            info.FrameLength = obj.FrameLength;
            info.NumSlots = nSlots;
            info.NumPilotBlocks = pilotCount;
            info.PilotPositions = pilotPositions; % positions in complete PLFRAME
            info.PLHeader = header;
            info.PLPayloadLength = numel(payload);
            info.PLFrameLength = numel(frame);
        end

        function header = MakePLHeader(obj, modcod, frameSizeBit, pilotBit)
            obj.requireDvb();
            if ~(isscalar(modcod) && modcod>=0 && modcod<=31 && modcod==floor(modcod) ...
                    && ismember(frameSizeBit,[0 1]) && ismember(pilotBit,[0 1]))
                error('ClassSig:Input', 'Invalid MODCOD/TYPE bits.');
            end
            sof = (dec2bin(hex2dec('18D2E82'),26)-'0').';
            b = [(dec2bin(modcod,5)-'0').'; frameSizeBit; pilotBit];
            generator = [ ...
                '01010101010101010101010101010101'; ...
                '00110011001100110011001100110011'; ...
                '00001111000011110000111100001111'; ...
                '00000000111111110000000011111111'; ...
                '00000000000000001111111111111111'; ...
                '11111111111111111111111111111111' ] - '0';
            y = mod(double(b(1:6)).'*double(generator),2).';
            pls = reshape([y y].',[],1);
            pls(2:2:end) = xor(logical(pls(2:2:end)),logical(b(7)));
            scramble = ('0111000110011101100000111100100101010011010000100010110111111010'-'0').';
            pls = mod(double(pls)+double(scramble),2);
            bits = [sof; pls];
            header = complex(zeros(90,1));
            header(1:2:end) = (1-2*bits(1:2:end))*(1+1i)/sqrt(2);
            header(2:2:end) = -(1-2*bits(2:2:end))*(1-1i)/sqrt(2);
        end

        function output = PulseShape(obj, symbols)
            obj.requireDvb();
            sps = obj.SamplesPerSymbol;
            up = complex(zeros((numel(symbols)-1)*sps+1,1));
            up(1:sps:end) = symbols(:);
            output = conv(up, obj.FilterTaps(:),'full');
        end

        function rotations = GetScramblingRotations(obj, nSymbols)
            % Public inspection method for isolated tests/integration.
            obj.requireDvb();
            if ~(isscalar(nSymbols) && nSymbols>=0 && nSymbols == floor(nSymbols) && ...
                    nSymbols <= 66420)
                error('ClassSig:Input', 'Invalid scrambling sequence length.');
            end
            rotations = obj.ScramblingRotations(1:nSymbols);
        end
    end

    methods (Access = private)
        function requireDvb(obj)
            if ~strcmpi(obj.Mode, 'DVB-S2') || obj.isTransparent
                error('ClassSig:Mode', 'This method requires enabled DVB-S2 mode.');
            end
        end
    end

    methods (Static, Access = private)
        function value = fieldOr(s, name, defaultValue)
            if isfield(s, name)
                value = s.(name);
            else
                value = defaultValue;
            end
        end

        function mc = findModcod(modulation, rate)
            switch modulation
                case 'QPSK'
                    rates = {'1/4','1/3','2/5','1/2','3/5','2/3', ...
                             '3/4','4/5','5/6','8/9','9/10'};
                    start = 1;
                case '8PSK'
                    rates = {'3/5','2/3','3/4','5/6','8/9','9/10'};
                    start = 12;
                case '16APSK'
                    rates = {'2/3','3/4','4/5','5/6','8/9','9/10'};
                    start = 18;
                case '32APSK'
                    rates = {'3/4','4/5','5/6','8/9','9/10'};
                    start = 24;
            end
            idx = find(strcmp(rate,rates),1);
            if isempty(idx)
                error('ClassSig:Config', ...
                    'Unsupported DVB-S2 MODCOD: %s %s.', modulation,rate);
            end
            mc = start + idx - 1;
        end

        function lut = makeConstellation(modulation, rate)
            switch modulation
                case 'QPSK'
                    labels = {'00','10','11','01'};
                    angles = (45:90:315);
                    radii = ones(1,4);
                case '8PSK'
                    labels = {'000','100','110','010','011','111','101','001'};
                    angles = [45:45:315 0];
                    radii = ones(1,8);
                case '16APSK'
                    r = {'2/3','3/4','4/5','5/6','8/9','9/10'};
                    v = [3.15 2.85 2.75 2.70 2.60 2.57];
                    gamma = v(strcmp(rate,r));
                    r1 = 2/sqrt(1+3*gamma^2);
                    labels = {'1100','1110','1111','1101', ...
                        '0100','0000','1000','1010','0010','0110', ...
                        '0111','0011','1011','1001','0001','0101'};
                    angles = [45 135 225 315 15:30:345];
                    radii = [r1*ones(1,4) r1*gamma*ones(1,12)];
                case '32APSK'
                    r = {'3/4','4/5','5/6','8/9','9/10'};
                    g1 = [2.84 2.72 2.64 2.54 2.53];
                    g2 = [5.27 4.87 4.64 4.33 4.30];
                    v1 = g1(strcmp(rate,r));
                    v2 = g2(strcmp(rate,r));
                    r1 = sqrt(8/(1+3*v1^2+4*v2^2));
                    labels = {'10001','10101','10111','10011', ...
                        '10000','00000','00001','00101','00100','10100', ...
                        '10110','00110','00111','00011','00010','10010', ...
                        '11000','01000','11001','01001','01101','11101', ...
                        '01100','11100','11110','01110','11111','01111', ...
                        '01011','11011','01010','11010'};
                    angles = [45 135 225 315 15:30:345 0:22.5:337.5];
                    radii = [r1*ones(1,4),r1*v1*ones(1,12),r1*v2*ones(1,16)];
            end
            sizeM = numel(labels);
            lut = complex(zeros(sizeM,1));
            used = false(sizeM,1);
            for k = 1:sizeM
                idx = bin2dec(labels{k})+1;
                if used(idx)
                    error('ClassSig:Internal','Duplicate constellation label.');
                end
                used(idx) = true;
                lut(idx) = radii(k)*exp(1i*angles(k)*pi/180);
            end
            if ~all(used) || abs(mean(abs(lut).^2)-1)>1e-12
                error('ClassSig:Internal','Invalid DVB-S2 constellation.');
            end
        end

        function taps = makeRrc(alpha, span, sps)
            % Continuous-time unit-energy square-root raised cosine, sampled.
            t = (-span/2:1/sps:span/2).';
            taps = zeros(size(t));
            for k=1:numel(t)
                x=t(k);
                if abs(x) < 1e-12
                    taps(k) = 1+alpha*(4/pi-1);
                elseif abs(abs(4*alpha*x)-1) < 1e-10
                    taps(k) = alpha/sqrt(2) * ( ...
                        (1+2/pi)*sin(pi/(4*alpha)) + ...
                        (1-2/pi)*cos(pi/(4*alpha)));
                else
                    taps(k) = (sin(pi*x*(1-alpha)) + ...
                        4*alpha*x*cos(pi*x*(1+alpha))) / ...
                        (pi*x*(1-(4*alpha*x)^2));
                end
            end
            taps = taps/norm(taps);
        end

        function rotations = makeGoldRotations(n)
            % ETSI 5.5.4: x,y m-sequences of period 2^18-1.
            N=2^18-1;
            x=false(N,1);
            y=true(N,1);
            x(1)=true;
            for k=1:N-18
                x(k+18)=xor(x(k+7),x(k));
                y(k+18)=xor(xor(y(k+10),y(k+7)),xor(y(k+5),y(k)));
            end
            indices=mod((0:N-1).'+n,N)+1;
            z=x(indices)~=y;
            maxLength=66420;
            lo=z(1:maxLength);
            hi=z(mod((0:maxLength-1).'+131072,N)+1);
            index=1+double(lo)+2*double(hi);
            rotationTable=[1;1i;-1;-1i];
            rotations=rotationTable(index);
        end
    end
end
