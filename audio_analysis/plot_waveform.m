function plot_waveform(cfg, allT0)
% PLOT_WAVEFORM Waveform plot depicting full session sound amplitudes.
% INPUTS:
%   cfg: config file for audio location
%   allT0: time stamps for event alignment

    nConds     = numel(cfg.conditions);
    condColors = [
        0.45  0.70  0.95;
        0.25  0.60  0.95;
        0.05  0.20  0.60;
    ];
    zoomYLims = [-0.1  0.1;
                 -0.1  0.1];
    zoomStart = 285;
    zoomEnd   = 315;

    % --- Cache audio ---
    minDuration = inf;
    audioCache  = cell(nConds, 1);
    tAxisCache  = cell(nConds, 1);

    for c = 1:nConds
        [y, fs]  = audioread(cfg.conditions(c).audioFile);
        if size(y, 2) > 1, y = mean(y, 2); end
        audio_ts = seconds((0:length(y)-1) / fs) + cfg.conditions(c).audioStart;
        mask     = audio_ts >= allT0{c};
        tAxis    = seconds(audio_ts(mask) - allT0{c});
        y        = y(mask);
        minDuration   = min(minDuration, tAxis(end));
        audioCache{c} = y;
        tAxisCache{c} = tAxis;
    end

    % --- Plot ---
    fig = figure('Position', [100 100 1400 900]);
    mainAxHandles = gobjects(nConds, 1);

    for c = 1:nConds
        y     = audioCache{c};
        tAxis = tAxisCache{c};

        ax = subplot(nConds, 1, c);
        mainAxHandles(c) = ax;

        plot(ax, tAxis, y, 'Color', condColors(c,:), 'LineWidth', 0.5);
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

    % Force layout to settle before placing insets
    drawnow;

    % --- Add insets for rows A and B only ---
    for c = 1:nConds - 1
        y     = audioCache{c};
        tAxis = tAxisCache{c};
        ax    = mainAxHandles(c);

        % Shaded rectangle on main axes
        hold(ax, 'on');
        patch(ax, ...
            [zoomStart zoomEnd zoomEnd zoomStart], ...
            [-1 -1 1 1], ...
            [1 1 1], ...
            'FaceAlpha', 0.5, ...
            'EdgeColor', 'none');
        hold(ax, 'off');

        % Get main axes position and limits
        axPos    = get(ax, 'Position');
        xLimMain = xlim(ax);
        yLimMain = ylim(ax);

        % Inset size
        insetW = axPos(3) * 0.26;
        insetH = axPos(4) * 0.40;

        % Inset x position (right side of subplot)
        insetL = axPos(1) + axPos(3) * 0.72;

        % Find where y=0 sits in main axes in figure coordinates
        zeroFrac      = (0 - yLimMain(1)) / diff(yLimMain);
        zeroFigY      = axPos(2) + zeroFrac * axPos(4);

        % Align inset so its y=0 matches main axes y=0
        zeroFracInset = (0 - zoomYLims(c,1)) / diff(zoomYLims(c,:));
        insetB        = zeroFigY - zeroFracInset * insetH;

        axIn = axes(fig, 'Position', [insetL insetB insetW insetH]);
        set(axIn, 'Units', 'normalized');   % lock in normalized units
        disableDefaultInteractivity(axIn);  % prevent MATLAB from auto-adjusting

        % Plot zoomed segment
        mask_zoom = tAxis >= zoomStart & tAxis <= zoomEnd;
        plot(axIn, tAxis(mask_zoom), y(mask_zoom), ...
            'Color', condColors(c,:), 'LineWidth', 0.8);

        xlim(axIn, [zoomStart zoomEnd]);
        ylim(axIn, [zoomYLims(c,1) zoomYLims(c,2)]);
        grid(axIn, 'on');
        set(axIn, 'FontSize', 7, 'Box', 'on', ...
            'Color', [1 1 1], ...
            'XColor', [0.2 0.2 0.2], ...
            'YColor', [0.2 0.2 0.2]);
        yticks(axIn, [zoomYLims(c,1), 0, zoomYLims(c,2)]);
        xticklabels(axIn, {});
        xlabel(axIn, '');
        ylabel(axIn, '');
    end

    % Link only main subplot axes
    linkaxes(mainAxHandles, 'x');
    sgtitle('Full Session Waveform by Condition');
end