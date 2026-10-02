Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 4;
BER.BERNumRateDigits = 8;
BER.FERNumRateDigits = 5;
BER.BERPrecision = 5;
% BER.h2Precision = 0;
% BER.h2dBInitStep = 1;
% BER.h2dBMaxStep = 1;
% BER.h2dBMinStep = 1;

% End of Params


Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 16;

% End of Params


Source.NumBitsPerFrame = 2*3*4*5*8;
Mapper.Type = 'PSK';
Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 8;

% End of Params
Source.NumBitsPerFrame = 2*3*4*5*8;
% Mapper.Type = 'PSK';
Mapper.isTransparent = false;
Channel.isTransparent = false;
Mapper.ModulationOrder = 64;