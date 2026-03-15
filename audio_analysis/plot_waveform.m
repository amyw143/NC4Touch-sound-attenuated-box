function plot_waveform(allStats, cfg)
% PLOT_WAVEFORM  Plots mean waveform per event, overlaying box_open and
% box_closed conditions in a single figure with one subplot per event.
%
% INPUTS:
%   allStats - cell array of eventStats structs from main script
%   cfg      - config struct with cfg.conditions(c).extractedDir and .name

    condColors = {[0.2 0.6 1], [1 0.6 0.2]};  % box_closed, box_open
    nConds     = numel(cfg.conditions);
    eventIDs   = {allStats{1}.eventID};
    nEvents    = numel(eventIDs);

    % --- Layout ---
    nCols = 3;
    nRows = ceil(nEvents / nCols);
    figure('Position', [100 100 1200 300*nRows]);
    sgtitle('Mean Waveform by Event: Box Open vs Box Closed');

    for i = 1:nEvents
        ax = subplot(nRows, nCols, i);
        hold(ax, 'on');

        for c = 1:nConds
            extractedDir = cfg.conditions(c).extractedDir;
            eventName    = eventIDs{i};

            % Find all trials for this event
            pattern = fullfile(extractedDir, sprintf('%s_trial*.wav', eventName));
            files   = dir(pattern);
            if isempty(files)
                warning('No files found for event %s, condition %s', eventName, cfg.conditions(c).name);
                continue;
            end

            % Load all trials and average
            for t = 1:numel(files)
                [y, fs] = audioread(fullfile(extractedDir, files(t).name));
                if size(y, 2) > 1, y = mean(y, 2); end
                if t == 1
                    ySum = y;
                else
                    % Align lengths
                    minLen = min(length(ySum), length(y));
                    ySum   = ySum(1:minLen) + y(1:minLen);
                end
            end
            yMean = ySum / numel(files);
            tAxis = (0:length(yMean)-1) / fs;

            plot(ax, tAxis, yMean, 'Color', condColors{c}, 'LineWidth', 1);
        end

        title(ax, strrep(eventIDs{i}, '_', '\_'));
        xlabel(ax, 'Time (s)');
        ylabel(ax, 'Amplitude');
        grid(ax, 'on');
        hold(ax, 'off');
    end

    legend(strrep({cfg.conditions.name}, '_', '\_'), 'Position', [0.92 0.45 0.07 0.1]);
end