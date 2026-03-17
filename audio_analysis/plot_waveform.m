function plot_waveform(cfg, allEventTiming)
% PLOT_WAVEFORM  Plots full trimmed waveform for each condition overlaid,
% with shaded regions for each event window across all trials.
%
% INPUTS:
%   cfg            - config struct with cfg.conditions(c).trimmedFile and .name
%   allEventTiming - cell array (one per condition) of event timing structs
%                    each entry: {eventName, tStart, tEnd}

    nConds     = numel(cfg.conditions);

    % --- Plot waveform per condition ---
    figure('Position', [100 100 1400 900]);

    % Find shortest trimmed audio duration
    minDuration = inf;
    for c = 1:nConds
        info = audioinfo(cfg.conditions(c).trimmedFile);
        minDuration = min(minDuration, info.Duration);
    end

    % Find first Buzzer60 onset per condition
    buzzerOnsets = nan(1, nConds);
    for c = 1:nConds
        for k = 1:numel(allEventTiming{c})
            if strcmp(allEventTiming{c}{k}{1}, 'Buzzer60')
                buzzerOnsets(c) = allEventTiming{c}{k}{2};
                break;
            end
        end
    end
    tRef = min(buzzerOnsets);  % align to earliest onset

    for c = 1:nConds
        [y, fs] = audioread(cfg.conditions(c).trimmedFile);
        if size(y, 2) > 1, y = mean(y, 2); end
        tShift = buzzerOnsets(c) - tRef;
        tAxis  = (0:length(y)-1) / fs - tShift;

        ax = subplot(nConds, 1, c);
        plot(tAxis, y, 'Color', [0.3 0.4 0.8], 'LineWidth', 0.5);
        title(ax, strrep(cfg.conditions(c).name, '_', ' '));
        text(ax, 0.01, 0.95, char('A' + c - 1), ...
            'Units', 'normalized', ...
            'FontSize', 14, ...
            'FontWeight', 'bold', ...
            'VerticalAlignment', 'top');
        ylabel(ax, 'Amplitude');
        ylim(ax, [-1 1]);  % consistent y-axis across panels
        xlim(ax, [-tShift, minDuration - tShift]);
        grid(ax, 'on');
        if c == nConds
            xlabel(ax, 'Time (s)');
        end
    end
    linkaxes(findall(gcf, 'Type', 'axes'), 'x');  % shared x-axis
    sgtitle('Full Session Waveform by Condition');

