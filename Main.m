function Main
    clc;
    close all;
    rng(8, 'twister');

    %%  ФЛАГИ УПРАВЛЕНИЯ РАСЧЁТОМ
    runPart1  = 1;   % 1 — выполнить проверку тракта в канале без шума
    recalcPER = 0;   % 1 — пересчитать кривую PER, 0 — загрузить сохранённую

    %% Загрузка и поиск файлов
    perFileName = 'PER_curve.mat';

    % Переходим в папку проекта, чтобы ReadSetup нашла файл Setup.m.
    projectFolder = fileparts(mfilename('fullpath'));
    if isempty(projectFolder), projectFolder = pwd; end
    addpath(projectFolder);
    previousFolder = pwd;
    folderGuard = onCleanup(@() cd(previousFolder));
    cd(projectFolder);

    fprintf('Лабораторная работа DVB-S2 | задача 1 | команда 8\n');
    fprintf('32APSK | LDPC 5/6 | beta = 0,20 | пилоты включены\n\n');

    % Считываем настройки и применяем штатные функции исходной модели.
    parameterSets = ReadSetup('Russian');
    if numel(parameterSets) ~= 1
        error('Для этой лабораторной должен быть задан ровно один набор параметров в Setup.m.');
    end
    Params = SetParams(parameterSets{1}, 1, 'Russian');
    Params = CalcAndCheckParams(Params, 'Russian');

    outFolder = fullfile(projectFolder, 'Results_Task1_Team8');
    if ~exist(outFolder, 'dir'), mkdir(outFolder); end

    %%  ЧАСТЬ 1: Проверка тракта в канале БЕЗ ШУМА
    if runPart1
        fprintf('--- ЧАСТЬ 1: канал без шума (проверка тракта) ---\n');

        % Создаём предусмотренные моделью объекты передатчика и приёмника.
        Objs.Source      = ClassSource(Params, 'Russian');
        Objs.Encoder     = ClassEncoder(Params, 'Russian');
        Objs.Interleaver = ClassInterleaver(Params, 'Russian');
        Objs.Mapper      = ClassMapper(Params, 'Russian');
        Objs.Sig         = ClassSig(Params, 'Russian', Objs.Mapper.Constellation);
        Objs.Channel     = ClassChannel(Params, Objs, 'Russian');
        Objs.Stat        = ClassStat('Russian');

        % ------------------------- ПЕРЕДАТЧИК -------------------------
        Frame.TxData       = Objs.Source.Step();
        Frame.TxEncData    = Objs.Encoder.StepTx(Frame.TxData);
        Frame.TxIntData    = Objs.Interleaver.StepTx(Frame.TxEncData);
        Frame.TxModSymbols = Objs.Mapper.StepTx(Frame.TxIntData);
        Frame.TxSignal     = Objs.Sig.StepTx(Frame.TxModSymbols);

        % --------------------------- КАНАЛ ----------------------------
        [Frame.RxSignal, InstChannelParams] = Objs.Channel.Step(Frame.TxSignal, inf);

        % ------------------------- ПРИЁМНИК ---------------------------
        Frame.RxModSymbols = Objs.Sig.StepRx(Frame.RxSignal);
        Frame.RxIntData    = Objs.Mapper.StepRx(Frame.RxModSymbols, InstChannelParams);
        Frame.RxEncData    = Objs.Interleaver.StepRx(Frame.RxIntData);
        Frame.RxData       = Objs.Encoder.StepRx(Frame.RxEncData);

        % Считаем статистику в штатном объекте модели.
        Objs.Stat.Step(Frame);
        stats = struct();
        stats.Team               = 8;
        stats.Modulation         = '32APSK';
        stats.MODCOD             = 26;
        stats.LDPC               = '5/6';
        stats.RollOff            = 0.20;
        stats.Pilots             = true;
        stats.TransmittedPackets = Objs.Stat.NumTrPackets;
        stats.RecoveredPackets   = Objs.Stat.NumTrPackets - Objs.Stat.NumErPackets;
        stats.BitErrors          = Objs.Stat.NumErBits;
        stats.ByteErrors         = Objs.Stat.NumErBytes;
        stats.PacketErrors       = Objs.Stat.NumErPackets;
        stats.PER                = stats.PacketErrors / stats.TransmittedPackets;
        stats.DemapperBitErrors  = sum(Frame.TxIntData ~= Frame.RxIntData);
        stats.BBHeaderCRC        = Objs.Encoder.LastBBHeaderValid;
        stats.BCHCheck           = Objs.Encoder.LastBCHValid;
        stats.LDPCCheck          = Objs.Encoder.LastLDPCValid;
        stats.PacketCRC          = Objs.Encoder.LastPacketCRCValid;
        stats.PLHeaderMaxError   = Objs.Sig.LastHeaderError;
        stats.PilotMaxError      = Objs.Sig.LastPilotError;

        % Проверяем основное условие задачи: полное восстановление без шума.
        if ~isequal(Frame.TxData, Frame.RxData) || stats.DemapperBitErrors ~= 0 || ...
                stats.BitErrors ~= 0 || stats.ByteErrors ~= 0 || stats.PacketErrors ~= 0 || ...
                ~stats.BBHeaderCRC || ~stats.BCHCheck || ~stats.LDPCCheck || ~stats.PacketCRC
            error('Проверка не пройдена: переданные и восстановленные пакеты отличаются.');
        end

        % Сохраняем результаты рядом с моделью.
        txPackets     = Frame.TxData;
        rxPackets     = Frame.RxData;
        txSignal      = Frame.TxSignal;
        rxSymbols     = Frame.RxModSymbols;
        constellation = Objs.Mapper.Constellation;
        save(fullfile(outFolder, 'Результаты_задача1.mat'), ...
            'Params', 'stats', 'txPackets', 'rxPackets', 'txSignal', ...
            'rxSymbols', 'constellation');
        writeReport(fullfile(outFolder, 'Отчет_задача1.txt'), stats);

        

        % Сравнение принятых символов с идеальным созвездием.
        figure('Name', 'Принятые символы', 'Color', 'w');
        count = min(5000, numel(rxSymbols));
        plot(real(rxSymbols(1:count)), imag(rxSymbols(1:count)), '.');
        hold on;
        plot(real(constellation), imag(constellation), 'o', 'LineWidth', 1);
        axis equal; grid on;
        xlabel('Синфазная составляющая I');
        ylabel('Квадратурная составляющая Q');
        title('Принятые символы после согласованной фильтрации');
        legend('Принятые символы', 'Идеальные точки 32APSK', 'Location', 'best');

        fprintf('РЕЗУЛЬТАТ ЗАДАЧИ 1\n');
        fprintf('Передано пакетов MPEG-TS      : %d\n', stats.TransmittedPackets);
        fprintf('Восстановлено пакетов MPEG-TS : %d\n', stats.RecoveredPackets);
        fprintf('Ошибки бит / байт / пакетов   : %d / %d / %d\n', ...
            stats.BitErrors, stats.ByteErrors, stats.PacketErrors);
        fprintf('PER                           : %.6g\n', stats.PER);
        fprintf('CRC BBHEADER / BCH / LDPC / TS: %s / %s / %s / %s\n', ...
            passFail(stats.BBHeaderCRC), passFail(stats.BCHCheck), ...
            passFail(stats.LDPCCheck), passFail(stats.PacketCRC));
        fprintf('Проверка PLHEADER: %.6g | пилотов: %.6g\n', ...
            stats.PLHeaderMaxError, stats.PilotMaxError);
        fprintf('Все пакеты восстановлены без ошибок.\n\n');
    else
        fprintf('--- ЧАСТЬ 1 пропущена (runPart1 = false) ---\n\n');
    end

    %%  ЧАСТЬ 2: Кривая PER в канале с АБГШ
    perFileFull = fullfile(outFolder, perFileName);
    ruler = [];

    if recalcPER
        fprintf('--- ЧАСТЬ 2: канал AWGN, кривая PER (пересчёт) ---\n');

        ParamsAWGN = Params;
        ParamsAWGN.Channel.isTransparent = false;
        ParamsAWGN.Channel.Type = 'AWGN';

        ParamsAWGN.BER.h2dBInit       = 14.0;
        ParamsAWGN.BER.h2dBInitStep   = 0.05;
        ParamsAWGN.BER.h2dBMax        = 14.2;
        ParamsAWGN.BER.MinNumErFrames = 5;
        ParamsAWGN.BER.MaxNumTrFrames = 20000;

        ruler = ClassPERRuler(ParamsAWGN, 'Russian');
        ruler.Run(ParamsAWGN, 'Russian');

        savePERResults(perFileFull, ParamsAWGN, ruler);
        fprintf('Кривая PER сохранена: %s\n', perFileFull);
    else
        fprintf('--- ЧАСТЬ 2: загрузка ранее сохранённой кривой PER ---\n');
        S = load(perFileFull);
        ruler = S.ruler;
        if isfield(S, 'ParamsAWGN'), ParamsAWGN = S.ParamsAWGN; end
        fprintf('Загружено точек: %d (из %s)\n', numel(ruler.h2dBs), perFileFull);
    end

    figure('Name', 'PER vs Eb/N0', 'Color', 'w');
    semilogy(ruler.h2dBs, ruler.PER, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6);
    grid on;
    set(gca, 'YScale', 'log');
    xlim([0, 15]);
    ylim([1e-8, 1]);
    xlabel('E_b/N_0 (dB)');
    ylabel('PER (по пакетам MPEG-TS)');
    title('DVB-S2 32APSK LDPC 5/6, канал AWGN');
    hold on;
    x56 = [14.18, 14.24, 14.27, 14.28, 14.30, 14.33];
    y56 = [1e-01, 5e-03, 1e-03, 1e-04, 1e-05, 1.5e-06];
    semilogy(x56, y56, 'ks-', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'MarkerFaceColor', 'k');
    text(x56(1), y56(1)*1.5, '5/6', 'HorizontalAlignment', 'center', ...
        'BackgroundColor', 'yellow', 'FontWeight', 'bold');
    hold off;

    fprintf('\nГотово. Результаты в папке %s\n', outFolder);
end

%%  Вспомогательные функции отчёта
function writeReport(fileName, stats)
    fid = fopen(fileName, 'w', 'n', 'UTF-8');
    if fid < 0, error('Не удалось создать текстовый отчёт.'); end
    guard = onCleanup(@() fclose(fid));
    fprintf(fid, 'Лабораторная работа: приём сигналов DVB-S2 в канале с АБГШ\n');
    fprintf(fid, 'Задача 1. Команда 8.\n\n');
    fprintf(fid, 'Модуляция: %s\n', stats.Modulation);
    fprintf(fid, 'MODCOD: %d\n', stats.MODCOD);
    fprintf(fid, 'Скорость LDPC: %s\n', stats.LDPC);
    fprintf(fid, 'Коэффициент скругления спектра: %.2f\n', stats.RollOff);
    fprintf(fid, 'Пилоты: включены\nКанал: без шума\n\n');
    fprintf(fid, 'Передано пакетов: %d\n', stats.TransmittedPackets);
    fprintf(fid, 'Восстановлено пакетов: %d\n', stats.RecoveredPackets);
    fprintf(fid, 'Ошибок бит: %d\nОшибок байт: %d\nОшибок пакетов: %d\n', ...
        stats.BitErrors, stats.ByteErrors, stats.PacketErrors);
    fprintf(fid, 'PER: %.12g\n\n', stats.PER);
    fprintf(fid, 'CRC BBHEADER: %s\nBCH: %s\nLDPC: %s\nCRC-маркеры TS: %s\n', ...
        passFail(stats.BBHeaderCRC), passFail(stats.BCHCheck), ...
        passFail(stats.LDPCCheck), passFail(stats.PacketCRC));
    fprintf(fid, 'Максимальная ошибка символов PLHEADER: %.8g\n', stats.PLHeaderMaxError);
    fprintf(fid, 'Максимальная ошибка пилотов: %.8g\n', stats.PilotMaxError);
    fprintf(fid, '\nИтог: все исходные пакеты MPEG-TS восстановлены без ошибок.\n');
end

function value = passFail(condition)
    if condition, value = 'ПРОЙДЕНО'; else, value = 'ОШИБКА'; end
end

%% Сохранение результатов расчёта PER
function savePERResults(fileName, ParamsAWGN, ruler)
    h2dBs   = ruler.h2dBs;
    PER     = ruler.PER;
    savedAt = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<DATST,TNOW1>
    save(fileName, 'ParamsAWGN', 'ruler', 'h2dBs', 'PER', 'savedAt', '-v7.3');
end
