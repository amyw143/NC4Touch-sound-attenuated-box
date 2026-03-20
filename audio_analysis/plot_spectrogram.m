function plot_spectrogram(cfg, allEventTiming, allT0)
% PLOT_SPECTROGRAM  Plots full trimmed audio spectrogram per condition,
% stacked vertically with shared x-axis, aligned by first Buzzer60 onset.
%
% INPUTS:
%   cfg            - config struct with cfg.conditions(c).trimmedFile and .name
%   allEventTiming - cell array (one per condition) of event timing structs
%                    each entry: {eventName, tStart, tEnd}

    nConds = numel(cfg.conditions);

    % --- Spectrogram settings ---
    winSamples = 2048;
    overlap    = round(winSamples * 0.50);
    nfft       = winSamples;

    % --- Find shortest trimmed audio duration ---
    minDuration = inf;
    for c = 1:nConds
        info = audioinfo(cfg.conditions(c).trimmedFile);
        minDuration = min(minDuration, info.Duration);
    end

    % --- Plot ---
    figure('Position', [100 100 1400 900]);

    for c = 1:nConds
        [y, fs] = audioread(cfg.conditions(c).trimmedFile);
        if size(y, 2) > 1, y = mean(y, 2); end
        targetFs = 44100; % Downsample for computational speed
        y  = resample(y, targetFs, fs);
        fs = targetFs;

        ax = subplot(nConds, 1, c);
        
        [~, f, t, p] = spectrogram(y, winSamples, overlap, nfft, fs);
        imagesc(ax, t, f/1000, 10*log10(p));
        axis(ax, 'xy');
        colormap(ax, 'turbo');
        clim(ax, [-120 -40]);
        xlim(ax, [0 minDuration]);

        % Mark Buzzer60 event windows
        hold(ax, 'on');
        for k = 1:numel(allEventTiming{c})
            if strcmp(allEventTiming{c}{k}{1}, 'Buzzer60')
                tStart = allEventTiming{c}{k}{2};
                tEnd   = allEventTiming{c}{k}{3};
                xline(ax, tStart, 'w--', 'LineWidth', 1, 'HandleVisibility', 'off');
                xline(ax, tEnd,   'w:',  'LineWidth', 1, 'HandleVisibility', 'off');
            end
        end
        hold(ax, 'off');

        ylim(ax, [0.2 fs/2000]);  % 0.2kHz to Nyquist in kHz
        ylabel(ax, 'Frequency (kHz)');
        title(ax, strrep(cfg.conditions(c).name, '_', ' '));
        ylabel(ax, 'Frequency (kHz)');
        if c == nConds
            xlabel(ax, 'Time (s)');
        end

        % A/B/C label
        text(ax, 0.01, 0.95, char('A' + c - 1), ...
            'Units', 'normalized', ...
            'FontSize', 14, ...
            'FontWeight', 'bold', ...
            'VerticalAlignment', 'top', ...
            'Color', 'white');
    end

    linkaxes(findall(gcf, 'Type', 'axes'), 'x');
    sgtitle('Full Session Spectrogram by Condition');
end