% ===== Команда 8: 32APSK, R=5/6, beta=0.20, pilots=on =====
% Вход: 35 MPEG-TS пакетов по 1504 бит = 52640 бит (DFL)
Source.NumBitsPerFrame = 35*1504;   % 52640

% Mode adaptation: BBHEADER (80) + DATA FIELD (DFL=52640)
ModeAdaptation.UPL     = 1504;
ModeAdaptation.DFL     = 52640;
ModeAdaptation.K_BCH   = 53840;     % = N_BCH для R=5/6
ModeAdaptation.MATYPE1 = 0xF2;      % SIS, CCM, RO=10 (beta=0.20)
ModeAdaptation.MATYPE2 = 0x00;
ModeAdaptation.SYNC    = 0x47;
ModeAdaptation.SYNCD   = 0x0000;

% Stream adaptation: padding = K_BCH - 80 - DFL = 1120
StreamAdaptation.K_BCH = 53840;
StreamAdaptation.DFL   = 52640;

% FEC: BCH + LDPC для R=5/6 (Table 1 PDF)
Encoder.isTransparent = false;
Encoder.BCH_cwLen     = 54000;      % N_BCH
Encoder.BCH_k         = 53840;      % K_BCH
Encoder.N             = 64800;      % n_ldpc
Encoder.K             = 54000;      % k_ldpc
Encoder.Q             = 30;         % (64800-54000)/360

% Interleaver: 32APSK -> 5 столбцов x 12960 строк (Table 2 PDF)
Interleaver.isTransparent = false;

% Sig: 32APSK R=5/6, beta=0.20, pilots=on
Sig.Mode             = 'DVB-S2';
Sig.isTransparent    = false;
Sig.Modulation       = '32APSK';
Sig.CodeRate         = '5/6';
Sig.FrameLength      = 64800;
Sig.Pilots           = true;
Sig.Rolloff          = 0.20;
Sig.Span             = 10;
Sig.SamplesPerSymbol = 4;
Sig.SymbolRate       = 1e6;
Sig.ScramblingCode   = 0;
Sig.InputFormat      = 'bits';
Sig.OutputFormat     = 'baseband';

% Сохранение
Common.SaveFileName     = 'DVBS2_32APSK_R56';
Common.SaveDirName      = 'Results';
Common.NumWorkers       = 1;
Common.NumOneIterFrames = 1;
Common.Trace = 2;

% End of Params