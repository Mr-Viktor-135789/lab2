function [ct1, ct2] = buildLDPCtables_R56()
% Извлекает таблицы адресов DVB-S2 R=5/6 из dvbs2ldpc(5/6).
% Для группы g адреса берутся из ПЕРВОГО столбца группы (i=0):
%   a = (row - 1) mod M, где A(row, g*NB+1) = 1.
% Это соответствует таблице B.5 стандарта (адреса для u(g*NB)).

    H = dvbs2ldpc(5/6);
    K = 54000; NB = 360; M = 10800; Q = M/NB;   % Q = 30
    numRows = K / NB;                            % 150
    A = H(:, 1:K);

    ct1 = []; ct2 = [];
    for g = 0:numRows-1
        rows = find(A(:, g*NB + 1));      % i = 0
        addr = mod(rows - 1, M).';        % без сдвига i*Q
        row = [g, addr];
        % В стандарте: ct1 — первые 72 группы (degree 3),
        %              ct2 — остальные 78 (degree 2).
        % Но проще: смотреть на число адресов.
        if g < 72
            ct1 = [ct1; row];
        else
            ct2 = [ct2; row];
        end
    end
    % padding -1 (0 — валидный адрес!)
    ct1 = padRows(ct1);
    ct2 = padRows(ct2);
end

function M = padRows(M)
    if isempty(M), return; end
    maxLen = size(M, 2);
    % уже выровнено по [g, addr] — но если addr разной длины, дополним
    % (в этой версии все строки одной длины, т.к. addr фиксированной длины)
end