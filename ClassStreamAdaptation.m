classdef ClassStreamAdaptation < handle
    properties (SetAccess = private)
        K_BCH;
        DFL;
        PADDING_BITS;
        LogLanguage;
    end
    properties (SetAccess = private)
        bbFrame;
        scrambledBBFrame;
        padding;
    end
    methods
        function obj = ClassStreamAdaptation(Params, LogLanguage)
            % Конструктор совместим с общим стилем фреймворка
            if isfield(Params, 'StreamAdaptation')
                SA = Params.StreamAdaptation;
            else
                SA = struct();
            end

            % Если DFL не задан явно, берем из ModeAdaptation
            if isfield(Params, 'ModeAdaptation') && isfield(Params.ModeAdaptation, 'DFL')
                DFL_default = Params.ModeAdaptation.DFL;
            else
                DFL_default = 52640;
            end

            if ~isfield(SA, 'K_BCH'), SA.K_BCH = 53840;  end
            if ~isfield(SA, 'DFL'),   SA.DFL   = DFL_default; end

            obj.K_BCH = SA.K_BCH;
            obj.DFL   = SA.DFL;
            obj.PADDING_BITS = obj.K_BCH - 80 - obj.DFL;

            if obj.PADDING_BITS < 0
                error('K_BCH must be >= 80 + DFL');
            end

            obj.LogLanguage = LogLanguage;
        end

        function OutData = StepTx(obj, InData)
            % InData: [BBHEADER; DATA FIELD] (52720 бит)
            % OutData: scrambledBBFrame (53840 бит)
            
            if length(InData) ~= (80 + obj.DFL)
                error('Input length must be %d bits', 80 + obj.DFL);
            end
            
            bbHeader = InData(1:80);
            dataField = InData(81:end);
            
            % Формируем BBFRAME
            obj.padding = zeros(obj.PADDING_BITS, 1);
            obj.bbFrame = [bbHeader; dataField; obj.padding];

            % Скремблирование
            obj.scrambledBBFrame = obj.bbScrambling(obj.bbFrame);
            
            OutData = obj.scrambledBBFrame;
        end

        function OutData = StepRx(obj, InData)
            % InData: scrambledBBFrame (53840 бит)
            % OutData: [BBHEADER; DATA FIELD] (52720 бит)
            
            if length(InData) ~= obj.K_BCH
                error('Input length must be %d bits', obj.K_BCH);
            end
            
            obj.scrambledBBFrame = InData;
            
            % Дескремблирование (симметрично)
            obj.bbFrame = obj.bbScrambling(InData);
            
            % Отбрасываем padding и возвращаем BBHEADER + DATA FIELD
            OutData = obj.bbFrame(1 : 80 + obj.DFL);
        end

        function results = getIntermediateResults(obj)
            results.bbFrame          = obj.bbFrame;
            results.scrambledBBFrame = obj.scrambledBBFrame;
            results.padding          = obj.padding;
        end

        function scrambled = bbScrambling(obj, bbFrame)
            % PRBS: 1 + X^14 + X^15
            initSeq = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];
            r = initSeq;
            scrambled = zeros(size(bbFrame));
            for i = 1:length(bbFrame)
                p = xor(r(14), r(15));
                scrambled(i) = xor(bbFrame(i), p);
                r = [p, r(1:14)];
            end
        end
    end
end
