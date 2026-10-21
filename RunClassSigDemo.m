function [waveform, info] = RunClassSigDemo(team)
% Demonstrate ClassSig without depending on unfinished teammates' classes.
% Usage: [waveform,info]=RunClassSigDemo(3);
% This generates an arbitrary TEST FECFRAME (not valid BCH/LDPC codeword).
    if nargin<1, team=1; end
    names={'QPSK','QPSK','8PSK','8PSK','16APSK','16APSK','32APSK','32APSK'};
    rates={'1/2','3/4','3/5','3/4','2/3','3/4','3/4','5/6'};
    alphas=[.35 .20 .25 .35 .20 .25 .35 .20];
    if ~isscalar(team) || team<1 || team>8 || team~=floor(team)
        error('RunClassSigDemo:Team', 'Choose team 1..8.');
    end
    p.Sig.Mode = 'DVB-S2';
    p.Sig.isTransparent = false;
    p.Sig.Modulation = names{team};
    p.Sig.CodeRate = rates{team};
    p.Sig.FrameLength = 64800;
    p.Sig.Pilots = true;
    p.Sig.Rolloff = alphas(team);
    p.Sig.Span = 10;
    p.Sig.SamplesPerSymbol = 4;
    p.Sig.SymbolRate = 1e6;
    p.Sig.ScramblingCode = 0;
    p.Sig.InputFormat = 'bits';
    p.Sig.OutputFormat = 'baseband';
    sig = ClassSig(p, 'English');
    rng(17);
    testFecBits = randi([0 1],64800,1);
    [waveform,info] = sig.StepTx(testFecBits);
    fprintf('Team %d: %s, FEC %s, rolloff %.2f\n', ...
        team,names{team},rates{team},alphas(team));
    fprintf('PLFRAME: %d symbols, %d pilots, waveform: %d samples\n', ...
        info.PLFrameLength,numel(info.PilotPositions),numel(waveform));
    figure('Name','DVB-S2 ClassSig demonstration');
    limit = min(numel(info.PLSymbols),2090);
    plot(real(info.PLSymbols(91:limit)), ...
         imag(info.PLSymbols(91:limit)), '.');
    axis equal; grid on;
    xlabel('I'); ylabel('Q'); title('Scrambled PL payload constellation (first 2000 symbols)');
end
