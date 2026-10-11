clc; clear;

Params.Interleaver.isTransparent = false;
Params.Encoder.isTransparent     = false;

LogLanguage = 'ru';

il = ClassInterleaver(Params, LogLanguage);
enc = ClassEncoder(Params, LogLanguage);

InData_ilv = [1 0 1 1 0 1];          % 6 бит
OutData_ilv = il.StepTx(InData_ilv);
disp(OutData_ilv);

InData_enc = [1 0 1 1 0];            % 5 бит
code = enc.StepTx(InData_enc);
disp(code);

[genpoly, t] = bchgenpoly(15, 5);
disp(t); 
disp(genpoly);