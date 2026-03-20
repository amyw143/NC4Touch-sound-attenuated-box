function plot_waveform(cfg, allT0)
% PLOT_WAVEFORM  Plots full session waveform per condition from raw audio,
% stacked vertically with shared x-axis, trimmed to shortest clip from T0.
%
% INPUTS:
%   cfg            - config struct with cfg.conditions(c).audioFile and .name
%   allEventTiming - cell array of event timing structs per condition (unused, reserved)
%   allT0          - cell array of T0 datetimes per condition
 
    nConds = numel(cfg.conditions);
 
    condColors = [
        0.45  0.70  0.95;   % light blue  — box_closed
        0.25  0.60  0.95;   % medium blue — box_open
        0.05  0.20  0.60;   % deep navy   — internal_sound
    ];
 
    % --- Find shortest duration from T0 ---
    minDuration = inf;
    for c = 1:nConds
        [y, fs]  = audioread(cfg.conditions(c).audioFile);
        audio_ts = seconds((0:length(y)-1) / fs) + cfg.conditions(c).audioStart;
        minDuration = min(minDuration, seconds(audio_ts(end) - allT0{c}));
    end
 
    % --- Plot ---
    figure('Position', [100 100 1400 900]);
 
    for c = 1:nConds
        [y, fs] = audioread(cfg.conditions(c).audioFile);
        if size(y, 2) > 1, y = mean(y, 2); end
 
        audio_ts = seconds((0:length(y)-1) / fs) + cfg.conditions(c).audioStart;
        mask     = audio_ts >= allT0{c};
        tAxis    = seconds(audio_ts(mask) - allT0{c});
        y        = y(mask);
 
        ax = subplot(nConds, 1, c);
        plot(tAxis, y, 'Color', condColors(c,:), 'LineWidth', 0.5);
        title(ax, strrep(cfg.conditions(c).name, '_', ' '));
        ylabel(ax, 'Amplitude');
        ylim(ax, [-1 1]);
        xlim(ax, [0 minDuration]);
        grid(ax, 'on');
        text(ax, 0.01, 0.95, char('A' + c - 1), ...
            'Units', 'normalized', 'FontSize', 14, ...
            'FontWeight', 'bold', 'VerticalAlignment', 'top');
 
        if c == nConds, xlabel(ax, 'Time (s)'); end
    end
 
    linkaxes(findall(gcf, 'Type', 'axes'), 'x');
    sgtitle('Full Session Waveform by Condition');
end