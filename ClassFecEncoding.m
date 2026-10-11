clc; clear;

Params.Interleaver.isTransparent = false;
Params.Encoder.isTransparent     = false;

LogLanguage = 'ru';

il  = ClassInterleaver(Params, LogLanguage);
enc = ClassEncoder(Params, LogLanguage);

%% --- Перемежение (тест) ---
InData_ilv  = [1 0 1 1 0 1];
OutData_ilv = il.StepTx(InData_ilv);
fprintf('Interleaver: [%s] -> [%s]\n', ...
    num2str(InData_ilv), num2str(OutData_ilv));

%% --- Эталон BCH(15,5) ---
[genpoly, t] = bchgenpoly(15, 5);
fprintf('\nBCH(15,5) эталон: t=%d, genpoly (deg=%d)\n', t, numel(genpoly.x)-1);

%% ============ ТЕСТ 1: BCH ============
fprintf('\n===== ТЕСТ 1: BCH =====\n');
enc.Mode = 'BCH';
InData_enc = [1 0 1 1 0];
code1 = enc.StepTx(InData_enc);
fprintf('Вход (%d бит):  [%s]\n', numel(InData_enc), num2str(InData_enc));
fprintf('Выход (%d бит): [%s]\n', numel(code1), num2str(code1));

% Проверка: code делится на genpoly без остатка
[~, r] = deconv(code1, double(genpoly.x));
fprintf('Остаток: %s (должны быть нули)\n', mat2str(mod(real(r),2)));

%% ============ ТЕСТ 2: LDPC ============
fprintf('\n===== ТЕСТ 2: LDPC =====\n');
enc.Mode = 'LDPC';
InData_ldpc = [1 0 1 1 0];    % короткий вход, добьётся нулями до K=53840
try
    code2 = enc.StepTx(InData_ldpc);
    fprintf('Вход (%d бит) -> Выход (%d бит)\n', numel(InData_ldpc), numel(code2));
    fprintf('Первые 20 бит выхода: [%s]\n', num2str(code2(1:20)));
catch ME
    fprintf('Ошибка LDPC: %s\n', ME.message);
    fprintf('Проверьте наличие файла ldpc.mat с переменной R_5_6.ct1/ct2\n');
end

%% ============ ТЕСТ 3: Каскад BCH + LDPC ============
fprintf('\n===== ТЕСТ 3: Каскад BCH+LDPC =====\n');
enc.Mode = 'BCH+LDPC';
try
    code3 = enc.StepTx(InData_enc);
    fprintf('Вход (%d бит) -> Выход (%d бит)\n', numel(InData_enc), numel(code3));
    fprintf('Первые 20 бит выхода: [%s]\n', num2str(code3(1:20)));
    fprintf('Биты 1..15 (BCH-часть): [%s]\n', num2str(code3(1:15)));
    fprintf('Биты 16..20 (нули-добивка): [%s]\n', num2str(code3(16:20)));
catch ME
    fprintf('Ошибка каскада: %s\n', ME.message);
end

%% ============ ТЕСТ 4: Прозрачный режим ============
fprintf('\n===== ТЕСТ 4: Прозрачный режим =====\n');
ParamsT.Interleaver.isTransparent = true;
ParamsT.Encoder.isTransparent     = true;
ilT  = ClassInterleaver(ParamsT, LogLanguage);
encT = ClassEncoder(ParamsT, LogLanguage);
outT = encT.StepTx(InData_enc);
fprintf('Вход:  [%s]\n', num2str(InData_enc));
fprintf('Выход: [%s] (должен совпасть с входом)\n', num2str(outT));

%% ============ Сводка ============
fprintf('\n===== ИТОГ =====\n');
fprintf('Interleaver: длина %d\n', numel(OutData_ilv));
fprintf('BCH:         длина %d\n', numel(code1));
if exist('code2','var'), fprintf('LDPC:        длина %d\n', numel(code2)); end
if exist('code3','var'), fprintf('BCH+LDPC:    длина %d\n', numel(code3)); end
if exist('outT','var'),  fprintf('Прозрачный:  длина %d\n', numel(outT));  end