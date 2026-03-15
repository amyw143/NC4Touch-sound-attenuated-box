function plot_spectrogram(allStats, cfg)
% PLOT_SPECTROGRAM  Plots spectrogram for trial 1 of each event, one figure
% per condition, with one subplot per event.
%
% INPUTS:
%   allStats - cell array of eventStats structs from main script
%   cfg      - config struct with cfg.conditions(c).extractedDir and .name

    eventIDs = {allStats{1}.eventID};
    nEvents  = numel(eventIDs);
    nConds   = numel(cfg.conditions);

    % --- Spectrogram settings ---
    winSamples = 4096;
    overlap    = round(winSamples * 0.75);
    nfft       = winSamples;

    % --- Layout ---
    nCols = 3;
    nRows = ceil(nEvents / nCols);

    for c = 1:nConds
        figure('Position', [100 100 1200 300*nRows]);
        sgtitle(sprintf('Spectrogram — %s (Trial 1)', strrep(cfg.conditions(c).name, '_', '\_')));

        for i = 1:nEvents
            extractedDir = cfg.conditions(c).extractedDir;
            eventName    = eventIDs{i};

            % Load trial 1
            fname = fullfile(extractedDir, sprintf('%s_trial1.wav', eventName));
            if ~isfile(fname)
                warning('File not found: %s', fname);
                continue;
            end
            [y, fs] = audioread(fname);
            if size(y, 2) > 1, y = mean(y, 2); end

            ax = subplot(nRows, nCols, i);
            spectrogram(y, winSamples, overlap, nfft, fs, 'yaxis');
            title(ax, strrep(eventName, '_', '\_'));
            xlabel(ax, 'Time (s)');
            ylabel(ax, 'Frequency (kHz)');

            % Limit colorbar range for consistency across subplots
            clim(ax, [-120 -40]);
        end

        colormap('jet');
    end
end