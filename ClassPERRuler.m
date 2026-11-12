classdef ClassPERRuler < handle
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
            Objs.Source      = ClassSource(Params, LogLanguage);
            Objs.Encoder     = ClassEncoder(Params, LogLanguage);
            Objs.Interleaver = ClassInterleaver(Params, LogLanguage);
            Objs.Mapper      = ClassMapper(Params, LogLanguage);
            Objs.Sig         = ClassSig(Params, LogLanguage, Objs.Mapper.Constellation);
            Objs.Channel     = ClassChannel(Params, Objs, LogLanguage);

            nPkts = Params.Source.NumTSPacketsPerFrame;

            fprintf('%-8s %-10s %-8s %-8s\n', ...
                'Eb/N0', 'PER', 'frames', 'errors');

            for idx = 1:numel(obj.h2dBs)
                h2dB = obj.h2dBs(idx);
                nErPkts = 0; f = 0;

                while f < obj.MaxFrames && nErPkts < obj.MinErrors
                    f = f + 1;
                    Frame = ClassFrameRunner.Run(Objs, h2dB);

                    for k = 1:nPkts
                        if ~isequal(Frame.TxData(k,:), Frame.RxData(k,:))
                            nErPkts = nErPkts + 1;
                        end
                    end
                end

                obj.NumTrFrames(idx)  = f;
                obj.NumErFrames(idx)  = 0;
                obj.NumTrPackets(idx) = f * nPkts;
                obj.NumErPackets(idx) = nErPkts;
                obj.PER(idx)          = nErPkts / max(f * nPkts, 1);

                fprintf('%-8.2f %-10.2e %-8d %-8d\n', ...
                    h2dB, obj.PER(idx), f, nErPkts);
            end

            obj.Saves(Params);
        end

        function Saves(obj, Params)
            Res.h2dBs        = obj.h2dBs;
            Res.PER          = obj.PER;
            Res.NumTrFrames  = obj.NumTrFrames;
            Res.NumTrPackets = obj.NumTrPackets;
            Res.NumErPackets = obj.NumErPackets;
            save(obj.FullSaveFileName, 'Res', 'Params');
            fprintf('Сохранено: %s\n', obj.FullSaveFileName);
        end

        function Plot(obj, varargin)
            p = inputParser;
            p.addParameter('Ref',   true,  @islogical);
            p.addParameter('Save',  false, @islogical);
            p.addParameter('Title', 'DVB-S2 32APSK LDPC 5/6, канал AWGN', @ischar);
            p.parse(varargin{:});
            opt = p.Results;

            fig = figure('Name', 'PER vs Eb/N0', 'Color', 'w');
            semilogy(obj.h2dBs, obj.PER, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6);
            grid on; set(gca, 'YScale', 'log');
            xlim([0, 15]); ylim([1e-8, 1]);
            xlabel('E_b/N_0 (dB)');
            ylabel('PER (по пакетам MPEG-TS)');
            title(opt.Title); hold on;

            if opt.Ref
                x56 = [14.18, 14.24, 14.27, 14.28, 14.30, 14.33];
                y56 = [1e-01, 5e-03, 1e-03, 1e-04, 1e-05, 1.5e-06];
                semilogy(x56, y56, 'ks-', 'LineWidth', 1.5, 'MarkerSize', 6, ...
                    'MarkerFaceColor', 'k');
                text(x56(1), y56(1)*1.5, '5/6', 'HorizontalAlignment', 'center', ...
                    'BackgroundColor', 'yellow', 'FontWeight', 'bold');
            end
            hold off;

            if opt.Save
                if isunix, delim = '/'; else, delim = '\'; end
                pngName = [obj.SaveDirName, delim, obj.SaveFileName, '_PER.png'];
                print(fig, pngName, '-dpng', '-r150');
                fprintf('График сохранён: %s\n', pngName);
            end
        end
    end
end