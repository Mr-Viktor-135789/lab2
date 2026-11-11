classdef ClassPERRuler < handle
    % Измеритель PER/FER по Eb/N0 в канале AWGN.

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
        FER;
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
            obj.MinErrors = BER.MinNumErFrames;
            if isempty(obj.MinErrors) || obj.MinErrors < 1
                obj.MinErrors = 30;
            end

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
            obj.FER          = nan(1, n);
            obj.NumTrFrames  = zeros(1, n);
            obj.NumErFrames  = zeros(1, n);
            obj.NumTrPackets = zeros(1, n);
            obj.NumErPackets = zeros(1, n);
        end

        function Run(obj, Params, LogLanguage)
            Objs.Source      = ClassSource(Params, LogLanguage);
            Objs.Encoder     = ClassEncoder(Params, LogLanguage);
            Objs.Interleaver = ClassInterleaver(Params, LogLanguage);
            Objs.Mapper      = ClassMapper(Params, LogLanguage);
            Objs.Sig         = ClassSig(Params, LogLanguage, Objs.Mapper.Constellation);
            Objs.Channel     = ClassChannel(Params, Objs, LogLanguage);
            Objs.Stat        = ClassStat(LogLanguage);

            nPkts = Params.Source.NumTSPacketsPerFrame;

            fprintf('%-8s %-10s %-10s %-8s %-8s\n', ...
                'Eb/N0', 'PER', 'FER', 'frames', 'errors');

            for idx = 1:numel(obj.h2dBs)
                h2dB = obj.h2dBs(idx);
                nErFrames = 0; nErPkts = 0; f = 0;

                while f < obj.MaxFrames && nErFrames < obj.MinErrors
                    f = f + 1;

                    Frame.TxData       = Objs.Source.Step();
                    Frame.TxEncData    = Objs.Encoder.StepTx(Frame.TxData);
                    Frame.TxIntData    = Objs.Interleaver.StepTx(Frame.TxEncData);
                    Frame.TxModSymbols = Objs.Mapper.StepTx(Frame.TxIntData);
                    Frame.TxSignal     = Objs.Sig.StepTx(Frame.TxModSymbols);

                    [Frame.RxSignal, Inst] = Objs.Channel.Step(Frame.TxSignal, h2dB);

                    try
                        Frame.RxModSymbols = Objs.Sig.StepRx(Frame.RxSignal);
                        Frame.RxIntData    = Objs.Mapper.StepRx(Frame.RxModSymbols, Inst);
                        Frame.RxEncData    = Objs.Interleaver.StepRx(Frame.RxIntData);
                        Frame.RxData       = Objs.Encoder.StepRx(Frame.RxEncData);
                    catch
                        Frame.RxData = zeros(size(Frame.TxData), 'uint8');
                    end

                    Objs.Stat.Step(Frame);
                    nErFrames = nErFrames + Objs.Stat.NumErFrames;
                    nErPkts   = nErPkts   + Objs.Stat.NumErPackets;
                    Objs.Stat.Reset();
                end

                obj.NumTrFrames(idx)  = f;
                obj.NumErFrames(idx)  = nErFrames;
                obj.NumTrPackets(idx) = f * nPkts;
                obj.NumErPackets(idx) = nErPkts;
                obj.FER(idx)          = nErFrames / max(f, 1);
                obj.PER(idx)          = nErPkts / max(f * nPkts, 1);

                fprintf('%-8.2f %-10.2e %-10.2e %-8d %-8d\n', ...
                    h2dB, obj.PER(idx), obj.FER(idx), f, nErFrames);
            end

            obj.Saves(Params);
        end

        function Saves(obj, Params)
            Res.h2dBs       = obj.h2dBs;
            Res.PER         = obj.PER;
            Res.FER         = obj.FER;
            Res.NumTrFrames = obj.NumTrFrames;
            Res.NumErFrames = obj.NumErFrames;
            Res.NumTrPackets= obj.NumTrPackets;
            Res.NumErPackets= obj.NumErPackets;
            save(obj.FullSaveFileName, 'Res', 'Params');
            fprintf('Сохранено: %s\n', obj.FullSaveFileName);
        end
    end
end