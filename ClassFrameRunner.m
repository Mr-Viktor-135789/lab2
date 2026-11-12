classdef ClassFrameRunner
    % Прогон одного кадра DVB-S2 через весь тракт Tx → Channel → Rx.
    methods (Static)
        function [Frame, Inst] = Run(Objs, h2dB)
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
            Frame.RxIntData    = Objs.Mapper.StepRx(Frame.RxModSymbols, Inst);
            Frame.RxEncData    = Objs.Interleaver.StepRx(Frame.RxIntData);
            Frame.RxData       = Objs.Encoder.StepRx(Frame.RxEncData);
        end
    end
end