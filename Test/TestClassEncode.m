%% ============================================================
%  ФИНАЛЬНЫЙ ТЕСТ ClassEncoder (BCH+LDPC, R=5/6, n=64800)
%  LDPC: своя реализация по H (acc = A*u, p через кумулятивную XOR)
%  Эталон: bchenc + dvbs2ldpc/ldpcEncode
% ============================================================
clear; clc; rng(1);

K_BCH  = 53840;
N_BCH  = 54000;
N_LDPC = 64800;
bb = randi([0 1], 1, K_BCH);
fprintf('===== ФИНАЛЬНЫЙ ТЕСТ ClassEncoder (R=5/6, n=64800) =====\n');
fprintf('Вход BBFRAME: %d бит\n', numel(bb));

Params.Encoder.isTransparent = false;
Params.Common.Trace          = 0;
enc = ClassEncoder(Params, 'ru');

% ---------- 1. BCH ----------
n_full = 65535; k_full = n_full - (N_BCH - K_BCH);
m = [bb(:); zeros(k_full - K_BCH, 1)];
c = double(bchenc(gf(m.'), n_full, k_full).x(:)).';
bch_ref = c(end - N_BCH + 1 : end);

bch_dut = enc.encodeBCH(bb);
n_err_bch = sum(bch_dut(:) ~= bch_ref(:));
assert(n_err_bch == 0, 'BCH: расхождений %d', n_err_bch);
fprintf('BCH : OK  (%d бит)\n', N_BCH);

% ---------- 2. LDPC ----------
H   = dvbs2ldpc(5/6);
cfg = ldpcEncoderConfig(H);
ldpc_ref = ldpcEncode(bch_ref(:), cfg).';

ldpc_dut = enc.encodeLDPC(bch_dut);
n_err_ldpc = sum(ldpc_dut(:) ~= ldpc_ref(:));
if n_err_ldpc ~= 0
    idx = find(ldpc_dut ~= ldpc_ref);
    fprintf('LDPC: расхождений %d (первое %d, последнее %d)\n', ...
        n_err_ldpc, idx(1), idx(end));
    fprintf('  u: %d, p: %d\n', ...
        sum(ldpc_dut(1:54000) ~= ldpc_ref(1:54000)), ...
        sum(ldpc_dut(54001:end) ~= ldpc_ref(54001:end)));
end
assert(n_err_ldpc == 0, 'LDPC: расхождений %d', n_err_ldpc);
fprintf('LDPC: OK  (%d бит, своя реализация по H)\n', N_LDPC);

% ---------- 3. StepTx ----------
fec_dut = enc.StepTx(bb);
assert(numel(fec_dut) == N_LDPC, 'StepTx: длина %d', numel(fec_dut));
assert(isequal(fec_dut(:), ldpc_ref(:)), ...
    'StepTx: расхождений %d', sum(fec_dut(:) ~= ldpc_ref(:)));
fprintf('FEC  : OK  (%d бит, rate = %.4f)\n', N_LDPC, K_BCH / N_LDPC);

% ---------- 4. Прозрачный режим ----------
ParamsT.Encoder.isTransparent = true;
ParamsT.Common.Trace          = 0;
encT = ClassEncoder(ParamsT, 'ru');
x = randi([0 1], 1, 1000);
y = encT.StepTx(x);
assert(isequal(y, x), 'isTransparent: данные изменились');
fprintf('TRANSPARENT: OK\n');

% ---------- 5. Короткий вход ----------
x_short = randi([0 1], 1, K_BCH - 10);
y_short = enc.StepTx(x_short);
assert(numel(y_short) == N_LDPC, ...
    'Короткий вход: длина %d', numel(y_short));
fprintf('SHORT INPUT: OK (дополнение до K, выход %d)\n', N_LDPC);

% ---------- 6. Синдром H*c^T = 0 ----------
syn = mod(H * fec_dut(:), 2);
assert(all(syn == 0), 'Синдром H*c^T != 0');
fprintf('СИНДРОМ: OK (H*c^T = 0)\n');

fprintf('\n===== ВСЕ ТЕСТЫ ПРОЙДЕНЫ =====\n');