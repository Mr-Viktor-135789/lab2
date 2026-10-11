clc; clear;
Params.Interleaver.isTransparent = false;
Params.Encoder.isTransparent   = false;
LogLanguage = 'ru';

il = ClassInterleaver(Params, LogLanguage);
enc = ClassEncoder(Params, LogLanguage);

% Interleaver
InData_ilv = [1 0 1 1 0 1];
OutData_ilv = il.StepTx(InData_ilv);
fprintf('Il вход : %s\n', num2str(InData_ilv));
    
fprintf('Il выход: %s\n', num2str(OutData_ilv));

% Эталон BCH
[genpoly, t] = bchgenpoly(15, 5);
fprintf('\n BCH(15,5):t=%d, deg=%d\n', t, numel(genpoly.x)-1);

% BCH
enc.Mode  = 'BCH';
InData_enc = [1 0 1 1 0];
code1   = enc.StepTx(InData_enc);
fprintf('\nBCH вход:  %s\n', num2str(InData_enc));
fprintf('BCH выход: %s\n', num2str(code1));

[~, r] = deconv(code1, double(genpoly.x));
fprintf('Остаток: %s\n', mat2str(mod(real(r),2)));

% LDPC
enc.Mode  = 'LDPC';
InData_ldpc = [1 0 1 1 0];
code2    = enc.StepTx(InData_ldpc);
fprintf('\n LDPC: %d бит -> %d бит\n', numel(InData_ldpc), numel(code2));
fprintf(' Первые 20: %s\n', num2str(code2(1:20)));

% BCH+LDPC
enc.Mode = 'BCH+LDPC';
code3  = enc.StepTx(InData_enc);
fprintf('\nBCH+LDPC: %d бит -> %d бит\n', numel(InData_enc), numel(code3));
fprintf('            %s\n', num2str(code3(1:20)));


