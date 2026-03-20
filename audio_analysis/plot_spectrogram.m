function plot_spectrogram(cfg, allEventTiming, allT0)
% PLOT_SPECTROGRAM  Plots full session spectrogram per condition from raw audio,
% stacked vertically with shared x-axis, trimmed to shortest clip from T0.
%
% INPUTS:
%   cfg            - config struct with cfg.conditions(c).audioFile and .name
%   allEventTiming - cell array of event timing structs per condition
%   allT0          - cell array of T0 datetimes per condition

    nConds = numel(cfg.conditions);

    % --- Spectrogram settings ---
    targetFs   = 44100;
    winSamples = 2048;
    overlap    = round(winSamples * 0.50);
    nfft       = winSamples;

    % --- Find shortest duration from T0 across conditions ---
    minDuration = inf;
    for c = 1:nConds
        [y, fs] = audioread(cfg.conditions(c).audioFile);
        audio_ts = seconds((0:length(y)-1) / fs) + cfg.conditions(c).audioStart;
        dur = seconds(audio_ts(end) - allT0{c});
        minDuration = min(minDuration, dur);
    end

    % --- Plot ---
    figure('Position', [100 100 1400 900]);

    for c = 1:nConds
        [y, fs] = audioread(cfg.conditions(c).audioFile);
        if size(y, 2) > 1, y = mean(y, 2); end

        % Trim to T0
        audio_ts = seconds((0:length(y)-1) / fs) + cfg.conditions(c).audioStart;
        mask     = audio_ts >= allT0{c};
        y        = y(mask);

        % Downsample for performance
        y  = resample(y, targetFs, fs);
        fs = targetFs;

        ax = subplot(nConds, 1, c);
        [~, f, t, p] = spectrogram(y, winSamples, overlap, nfft, fs);
        tOffset = t(1);
        fprintf('Condition %s: tOffset = %.4f s\n', cfg.conditions(c).name, tOffset);


        for k = 1:numel(allEventTiming{c})
            if strcmp(allEventTiming{c}{k}{1}, 'Buzzer60')
                fprintf('Condition %s: first Buzzer onset = %.4f s\n', cfg.conditions(c).name, allEventTiming{c}{k}{2});
                break;
            end
        end

        imagesc(ax, t - tOffset, f/1000, 10*log10(p));
        axis(ax, 'xy');
        colormap(ax, 'turbo');
        clim(ax, [-120 -40]);
        xlim(ax, [0 minDuration]);
        ylim(ax, [0.2 fs/2000]);
        ylabel(ax, 'Frequency (kHz)');

        title(ax, strrep(cfg.conditions(c).name, '_', ' '));

        % A/B/C label
        text(ax, 0.01, 0.95, char('A' + c - 1), ...
            'Units', 'normalized', ...
            'FontSize', 14, ...
            'FontWeight', 'bold', ...
            'VerticalAlignment', 'top', ...
            'Color', 'white');

        % Mark Buzzer60 event windows
        hold(ax, 'on');
        for k = 1:numel(allEventTiming{c})
            if strcmp(allEventTiming{c}{k}{1}, 'Buzzer60')
                tStart = allEventTiming{c}{k}{2} - tOffset;
                tEnd   = allEventTiming{c}{k}{3} - tOffset;
                xline(ax, tStart, 'w--', 'LineWidth', 1, 'HandleVisibility', 'off');
                xline(ax, tEnd,   'w:',  'LineWidth', 1, 'HandleVisibility', 'off');
            end
        end
        hold(ax, 'off');

        if c == nConds
            xlabel(ax, 'Time (s)');
        end
    end

    linkaxes(findall(gcf, 'Type', 'axes'), 'x');
    sgtitle('Full Session Spectrogram by Condition');
end
