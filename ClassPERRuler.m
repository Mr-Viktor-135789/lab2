classdef ClassPERRuler < handle
    % Измеритель PER по Eb/N0 в канале AWGN.

    properties (SetAccess = private)
        h2dBs;
        MaxFrames;
        MinErrors;
        SaveFileName;
        SaveDirName;
        FullSaveFileName;
        LogLanguage;
    end
    properties (SetAccess = private)
        PER;
        NumTrFrames;
        NumErFrames;
        NumTrPackets;
        NumErPackets;
    end
    methods
        function obj = ClassPERRuler(Params, LogLanguage)
            BER = Params.BER;
            Common = Params.Common;

            obj.h2dBs = BER.h2dBInit : BER.h2dBInitStep : BER.h2dBMax;

            obj.MaxFrames = BER.MaxNumTrFrames;
            if isempty(obj.MaxFrames) || isinf(obj.MaxFrames) || isnan(obj.MaxFrames)
                obj.MaxFrames = 3000;
            end
            % MinErrors — минимальное число ошибочных ПАКЕТОВ для остановки.
            obj.MinErrors = BER.MinNumErFrames;

            obj.SaveFileName = Common.SaveFileName;
            obj.SaveDirName  = Common.SaveDirName;
            obj.LogLanguage  = LogLanguage;

            if ~isfolder(obj.SaveDirName)
                mkdir(obj.SaveDirName);
            end
            if isunix, delim = '/'; else, delim = '\'; end
            obj.FullSaveFileName = [obj.SaveDirName, delim, ...
                obj.SaveFileName, '_PER.mat'];

            n = numel(obj.h2dBs);
            obj.PER          = nan(1, n);
            obj.NumTrFrames  = zeros(1, n);
            obj.NumErFrames  = zeros(1, n);
            obj.NumTrPackets = zeros(1, n);
            obj.NumErPackets = zeros(1, n);
        end

        function Run(obj, Params, LogLanguage)
            % Инициализация объектов
            Objs.Source      = ClassSource(Params, LogLanguage);
            Objs.Encoder     = ClassEncoder(Params, LogLanguage);
            Objs.Interleaver = ClassInterleaver(Params, LogLanguage);
            Objs.Mapper      = ClassMapper(Params, LogLanguage);
            Objs.Sig         = ClassSig(Params, LogLanguage, Objs.Mapper.Constellation);
            Objs.Channel     = ClassChannel(Params, Objs, LogLanguage);
            
            nPkts = Params.Source.NumTSPacketsPerFrame;

            fprintf('%-8s %-10s %-8s %-8s\n', ...
                'Eb/N0', 'PER', 'frames', 'errors');

            % Итеративный цикл по точкам SNR
            for idx = 1:numel(obj.h2dBs)
                h2dB = obj.h2dBs(idx);
                nErPkts = 0; f = 0;

                % Итеративный цикл набора статистики
                while f < obj.MaxFrames && nErPkts < obj.MinErrors
                    f = f + 1;

                    % --- ПЕРЕДАТЧИК ---
                    Frame.TxData       = Objs.Source.Step();
                    Frame.TxEncData    = Objs.Encoder.StepTx(Frame.TxData);
                    Frame.TxIntData    = Objs.Interleaver.StepTx(Frame.TxEncData);
                    Frame.TxModSymbols = Objs.Mapper.StepTx(Frame.TxIntData);
                    Frame.TxSignal     = Objs.Sig.StepTx(Frame.TxModSymbols);

                    % --- КАНАЛ ---
                    [Frame.RxSignal, Inst] = Objs.Channel.Step(Frame.TxSignal, h2dB);

                    % --- ПРИЁМНИК ---
                    Frame.RxModSymbols = Objs.Sig.StepRx(Frame.RxSignal);
                    
                    N0 = Inst.Variance; 
                    llr = Objs.Mapper.StepRxLLR(Frame.RxModSymbols, N0);
                    
                    llr = Objs.Interleaver.StepRx(llr);
                    
                    [infoBits, isConv] = Objs.Encoder.ldpcDecodeMinSum(llr, 50);
                    
                    % === ОТЛАДКА ДЕКОДЕРА ===
                    if idx == 1 && f <= 2
                        fprintf('  [DEBUG] LDPC: conv=%d, ones=%d\n', isConv, sum(infoBits));
                        txInfo = double(Frame.TxEncData(1:54000));
                        matchInfo = mean(txInfo == double(infoBits));
                        fprintf('  [DEBUG] Совпадение info после LDPC: %.2f%%\n', 100*matchInfo);
                    end
                    
                    bbScrambled = infoBits(1:53840);
                    
                    scr = Objs.Encoder.makeBBScrambler(53840);
                    bbBits = mod(double(bbScrambled(:)) + double(scr), 2);
                    
                    bbBytes = obj.bitsToBytes(bbBits);
                    
                    dataField = bbBytes(11:10 + 6580);
                    
                    Frame.RxData = zeros(nPkts, 188, 'uint8');
                    for k = 1:nPkts
                        offset = (k-1)*188 + 1;
                        Frame.RxData(k, :) = [uint8(71), dataField(offset+1 : offset+187).'];
                    end
                    
                    % === ОТЛАДКА СБОРКИ ===
                    if idx == 1 && f <= 2
                        fprintf('  [DEBUG] TxData(1,1:10): %s\n', num2str(Frame.TxData(1, 1:10)));
                        fprintf('  [DEBUG] RxData(1,1:10): %s\n', num2str(Frame.RxData(1, 1:10)));
                    end
                    
                    % Подсчёт ошибочных пакетов
                    for k = 1:nPkts
                        if ~isequal(Frame.TxData(k,:), Frame.RxData(k,:))
                            nErPkts = nErPkts + 1;
                        end
                    end
                end

                obj.NumTrFrames(idx)  = f;
                obj.NumErFrames(idx)  = 0;   % FER удалён
                obj.NumTrPackets(idx) = f * nPkts;
                obj.NumErPackets(idx) = nErPkts;
                obj.PER(idx)          = nErPkts / max(f * nPkts, 1);

                fprintf('%-8.2f %-10.2e %-8d %-8d\n', ...
                    h2dB, obj.PER(idx), f, nErPkts);
            end

            obj.Saves(Params);
        end

        function Saves(obj, Params)
            Res.h2dBs       = obj.h2dBs;
            Res.PER         = obj.PER;
            Res.NumTrFrames = obj.NumTrFrames;
            Res.NumTrPackets= obj.NumTrPackets;
            Res.NumErPackets= obj.NumErPackets;
            save(obj.FullSaveFileName, 'Res', 'Params');
            fprintf('Сохранено: %s\n', obj.FullSaveFileName);
        end
    end
    
    methods (Access = private)
        function bytes = bitsToBytes(~, bits)
            bits = uint8(bits(:));
            if mod(numel(bits), 8) ~= 0
                bits = [bits; zeros(8 - mod(numel(bits), 8), 1, 'uint8')];
            end
            weights = uint16([128; 64; 32; 16; 8; 4; 2; 1]);
            bytes = uint8(sum(double(reshape(bits, 8, [])) .* double(weights), 1)).';
        end
    end
end
