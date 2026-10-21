function TestClassSig()
% Stand-alone tests for DVB-S2 physical layer (no FEC classes required).
% Run from project directory: TestClassSig
    mods = {'QPSK','QPSK','8PSK','8PSK', ...
            '16APSK','16APSK','32APSK','32APSK'};
    rates = {'1/2','3/4','3/5','3/4', ...
             '2/3','3/4','3/4','5/6'};
    alphas = [0.35 0.20 0.25 0.35 0.20 0.25 0.35 0.20];
    modcods = [4 7 12 14 18 19 24 26];
    orders = [2 2 3 3 4 4 5 5];
    rng(42);

    for k = 1:8
        p = config(mods{k}, rates{k}, alphas(k));
        sig = ClassSig(p, 'English');
        data = randi([0 1],64800,1);
        [wave, info] = sig.StepTx(data);
        S = 64800/orders(k)/90;
        pilots = floor((S-1)/16);
        nPL = 90*(S+1)+36*pilots;
        assert(info.Modcod == modcods(k));
        assert(info.NumSlots == S);
        assert(info.NumPilotBlocks == pilots);
        assert(info.PLFrameLength == nPL);
        assert(numel(info.PilotPositions)==36*pilots);
        assert(numel(info.PLSymbols)==nPL);
        assert(numel(wave)==(nPL-1)*4+41);
        assert(all(isfinite(wave)));
        assert(all(abs(abs(info.PLHeader)-1)<1e-12));
        assert(norm(wave)>0);
        assert(abs(sum(abs(sig.MapBits(data)).^2)/numel(sig.MapBits(data))-1)<0.02);
        assert(all(diff(info.PilotPositions)==1 | diff(info.PilotPositions)>1));
        % Undo PL scrambling: all pilot locations must be (1+j)/sqrt(2).
        rotations = sig.GetScramblingRotations(nPL-90);
        if k==1
            table=[1;1i;-1;-1i];
            referenceGold='01111313131313331312222000133323'-'0';
            assert(isequal(rotations(1:32),table(referenceGold(:)+1)));
        end
        original = info.PLSymbols(91:end) ./ rotations;
        assert(max(abs(original(info.PilotPositions-90)-(1+1i)/sqrt(2)))<1e-11);
        % The binary SOF prefix is fixed by ETSI: 18D2E82 (26 bits).
        bitHeader = recoverHeaderBits(info.PLHeader);
        expectedSof = (dec2bin(hex2dec('18D2E82'),26)-'0').';
        assert(isequal(bitHeader(1:26),expectedSof));
        % Compare bits input with pre-mapped XFECFRAME input.
        p.Sig.InputFormat='symbols';
        mapper = ClassSig(p,'English');
        preMapped=sig.MapBits(data);
        [wave2, info2] = mapper.StepTx(preMapped);
        assert(isequal(wave,wave2));
        assert(isequal(info2.PLSymbols,info.PLSymbols));
        fprintf('PASS: team %d, %s %s, %d PL symbols, %d pilots\n', ...
            k,mods{k},rates{k},nPL,numel(info.PilotPositions));
    end

    p=config('QPSK','1/2',0.35);
    sig=ClassSig(p,'English');
    [wave,info]=sig.StepTx([]);
    assert(info.IsDummy && info.Modcod==0 && info.NumSlots==36);
    assert(info.PLFrameLength==90+36*90);
    assert(info.NumPilotBlocks==0);
    assert(numel(wave)==(90+36*90-1)*4+41);
    assert(max(abs(info.PLSymbols(91:end)./ ...
        sig.GetScramblingRotations(36*90)-(1+1i)/sqrt(2)))<1e-12);
    % PLS for dummy MODCOD=0 and TYPE=00 is the 64-bit scrambling vector.
    dummyBits=recoverHeaderBits(info.PLHeader);
    expected=('0111000110011101100000111100100101010011010000100010110111111010'-'0').';
    assert(isequal(dummyBits(27:90), expected));
    fprintf('PASS: dummy PLFRAME\n');

    p.Sig.Pilots=false;
    sig=ClassSig(p,'English');
    [~,info]=sig.StepTx(zeros(64800,1));
    assert(info.NumPilotBlocks==0 && info.PLFrameLength==90+64800/2);
    fprintf('PASS: no-pilots PLFRAME\n');

    p.Sig.Pilots=true;
    p.Sig.FrameLength=16200;
    sig=ClassSig(p,'English');
    [~,info]=sig.StepTx(zeros(16200,1));
    assert(info.NumSlots==90 && info.NumPilotBlocks==5);
    assert(info.PLFrameLength==90+8100+5*36);
    fprintf('PASS: short frame\n');

    p=config('QPSK','1/2',0.35);
    p.Sig.OutputFormat='rf';
    p.Sig.CarrierFrequency=0.75e6; % fs=4e6, Nyquist=2e6
    sig=ClassSig(p,'English');
    [rf,~]=sig.StepTx(zeros(64800,1));
    assert(isreal(rf) && all(isfinite(rf)));
    fprintf('PASS: optional real-RF quadrature output\n');

    p=config('QPSK','1/2',0.35);
    sig=ClassSig(p,'English');
    try
        sig.StepRx(1);
        error('TestClassSig:ExpectedError', 'StepRx must reject fake receiver.');
    catch ex
        assert(strcmp(ex.identifier,'ClassSig:ReceiverNotImplemented'));
    end
    try
        sig.StepTx(zeros(100,1));
        error('TestClassSig:ExpectedError', 'Invalid FEC size accepted.');
    catch ex
        assert(strcmp(ex.identifier,'ClassSig:Input'));
    end
    fprintf('PASS: errors on unsupported receiver and malformed input\n');

    legacy=ClassSig(struct('Sig',struct('isTransparent',true)),'English');
    assert(isequal(legacy.StepTx([0;1;0]),[0;1;0]));
    fprintf('PASS: legacy compatibility\n');
    fprintf('\nALL ClassSig tests passed.\n');
end

function p=config(modulation,rate,alpha)
    p.Sig=struct( ...
        'Mode','DVB-S2', 'isTransparent',false, ...
        'Modulation',modulation,'CodeRate',rate, ...
        'FrameLength',64800, 'Pilots',true, 'Rolloff',alpha, ...
        'SamplesPerSymbol',4,'Span',10,'SymbolRate',1e6, ...
        'ScramblingCode',0,'InputFormat','bits', ...
        'OutputFormat','baseband');
end

function bits=recoverHeaderBits(header)
    bits=zeros(90,1);
    bits(1:2:end) = round((1-real(header(1:2:end))*sqrt(2))/2);
    bits(2:2:end) = round((1+real(header(2:2:end))*sqrt(2))/2);
end
