function plot_zoom_inset(cfg, allT0)
% Plots zoomed waveform (275-315s) for conditions A and B only
% with y-axis limits of -0.05 to 0.01

    zoomStart = 275;
    zoomEnd   = 310;
    condColors = [
        0.45  0.70  0.95;
        0.25  0.60  0.95;
    ];

    figure('Position', [100 100 600 400]);

    for c = 1:2
        [y, fs]  = audioread(cfg.conditions(c).audioFile);
        if size(y, 2) > 1, y = mean(y, 2); end
        audio_ts = seconds((0:length(y)-1) / fs) + cfg.conditions(c).audioStart;
        mask     = audio_ts >= allT0{c};
        tAxis    = seconds(audio_ts(mask) - allT0{c});
        y        = y(mask);

        ax = subplot(2, 1, c);
        mask_zoom = tAxis >= zoomStart & tAxis <= zoomEnd;
        plot(ax, tAxis(mask_zoom), y(mask_zoom), ...
            'Color', condColors(c,:), 'LineWidth', 0.8);
        ylim(ax, [-0.05 0.05]);
        xlim(ax, [zoomStart zoomEnd]);
        yticks(ax, [-0.05, 0, 0.05]);
    end
end