% Параметры лабораторной работы: команда 8.
% DVB-S2: 32APSK, LDPC 5/6, beta = 0.20, пилоты включены.

Source.NumBitsPerFrame = 35 * 188 * 8;
Source.NumTSPacketsPerFrame = 35;

Encoder.isTransparent = false;
Encoder.CodeRate = '5/6';
Encoder.FECFrame = 'normal';

Interleaver.isTransparent = false;

% Type оставлен совместимым с исходной проверкой SetParams.m.
% Фактическое созвездие задаётся полем ModulationType.
Mapper.isTransparent = false;
Mapper.Type = 'PSK';
Mapper.ModulationType = '32APSK';
Mapper.ModulationOrder = 32;
Mapper.PhaseOffset = 0;
Mapper.SymbolMapping = 'Binary';
Mapper.DecisionMethod = 'Hard decision';

Sig.isTransparent = false;
Sig.Pilots = true;
Sig.MODCOD = 26;
Sig.Beta = 0.20;
Sig.RRCSpan = 10;
Sig.SamplesPerSymbol = 4;

% Идеальный канал: шум и замирания отключены.
Channel.isTransparent = true;

Common.NumWorkers = 1;
Common.SaveDirName = 'Results_Task1_Team8';
Common.SaveFileName = 'Task1_Team8';

% End of Params
