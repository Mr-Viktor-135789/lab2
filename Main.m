function Main(FirstParamsNum, Step4ParamsNum, LogLanguage)
% Главный запускаемый файл (только DVB-S2).

    clc; close all;

    function RunDVBS2(Params, ParamsNum, LogLanguage)
        fprintf('%s DVB-S2 point %d: %s R=%s beta=%.2f pilots=%d\n', ...
            datestr(now), ParamsNum, Params.Sig.Modulation, ...
            Params.Sig.CodeRate, Params.Sig.Rolloff, Params.Sig.Pilots);
    
        % --- 1. MPEG-TS (nPkt * UPL бит, каждый с 0x47) ---
        ma = ClassModeAdaptation(Params, LogLanguage);
        nPkt = ma.numPackets;  nUPL = ma.UPL;
        rng(17);
        tsBits = randi([0 1], nPkt*nUPL, 1);
        sync = [0;1;0;0;0;1;1;1];                      % 0x47
        for p = 1:nPkt
            tsBits((p-1)*nUPL + (1:8)) = sync;
        end
    
        % --- 2. ModeAdaptation (CRC-8 + BBHEADER) ---
        bb = ma.StepTx(tsBits);                         % 80 + DFL
    
        % --- 3. StreamAdaptation (padding + BB scrambling) ---
        sa = ClassStreamAdaptation(Params, LogLanguage);
        bbFrame = sa.StepTx(bb);                        
    
               % --- 4. Encoder (BCH + LDPC) ---
        enc = ClassEncoder(Params, LogLanguage);
        fecBits = enc.StepTx(bbFrame);

        % --- 4a. Трасса LDPC "деление в столбик" (демо, при Trace>=1) ---
        if isfield(Params,'Common') && isfield(Params.Common,'Trace') && Params.Common.Trace >= 1
            tr = TraceOfConver(Params.Common.Trace);
            tr.ldpcColumnDivisionTrace(6, 2, 6, ...
                [0 1 3 5; 1 0 2 4], [0 2 5], ...
                [1 0 1 1 0 1, 0 1 0 0 1 1, 1 1 0 1 0 1]);
        end                  
    
        % --- 5. ClassSig (PLFRAME + RRC) ---
        sig = ClassSig(Params, LogLanguage);
        [wave, info] = sig.StepTx(fecBits);

        if ~isfolder(Params.Common.SaveDirName)
            mkdir(Params.Common.SaveDirName);
        end
        Res = struct();
        Res.Sig            = Params.Sig;
        Res.Modcod         = info.Modcod;
        Res.NumSlots       = info.NumSlots;
        Res.NumPilotBlocks = info.NumPilotBlocks;
        Res.PilotPositions = info.PilotPositions;
        Res.PLFrameLength  = info.PLFrameLength;
        Res.Waveform       = wave;
        Res.SampleRate     = info.SampleRate;
    
        FullName = fullfile(Params.Common.SaveDirName, ...
            sprintf('%s_%02d.mat', Params.Common.SaveFileName, ParamsNum));
        save(FullName, 'Res', 'Params');
        fprintf('   saved: %s (%d symbols, %d pilots)\n', ...
            FullName, info.PLFrameLength, info.NumPilotBlocks);
    end
    if nargin < 1 || isempty(FirstParamsNum), FirstParamsNum = 1; end
    if nargin < 2 || isempty(Step4ParamsNum), Step4ParamsNum = 1; end
    if nargin < 3 || isempty(LogLanguage),    LogLanguage = 'Russian'; end
    if ~(strcmp(LogLanguage,'Russian') || strcmp(LogLanguage,'English'))
        error('Main:LogLanguage', 'LogLanguage must be Russian or English.');
    end

    Params = ReadSetup(LogLanguage);
    NumParams = numel(Params);

    if nargin == 1
        kVals = FirstParamsNum;
    else
        kVals = FirstParamsNum : Step4ParamsNum : NumParams;
    end
    if min(kVals) < 1 || max(kVals) > NumParams
        error('Main:Range', 'Invalid parameter set range.');
    end

    for k = kVals
        Params{k} = SetParams(Params{k}, k, LogLanguage);
        Params{k} = CalcAndCheckParams(Params{k}, LogLanguage);

        RunDVBS2(Params{k}, k, LogLanguage);
    end
end