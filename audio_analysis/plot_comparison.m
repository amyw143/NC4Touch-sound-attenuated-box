function plot_comparison(allStatsTables, conditionNames)
% PLOT_COMPARISON  Grouped bar plot of absolute mean dB SPL per event and
% condition, with error bars and significance stars.
%
% INPUTS:
%   allStatsTables - struct2table output of stats for all conditions
%   conditionNames - cell array of condition name strings (e.g. {'box_closed','box_open'})

    T1     = allStatsTables{1};
    x      = categorical(T1.eventID);
    nConds = numel(allStatsTables);
    yGrp   = cell2mat(cellfun(@(T) T.mean_dB, allStatsTables, 'UniformOutput', false));
    errGrp = cell2mat(cellfun(@(T) T.std_dB,  allStatsTables, 'UniformOutput', false));

    figure('Position', [100 100 900 500]);
    condColors = [
        0.85  0.92  1.00;   % light blue    — box_closed
        0.25  0.60  0.95;   % medium blue   — box_open
        0.05  0.20  0.60;   % deep navy     — internal_sound
        ];
    bg = bar(x, yGrp, 'grouped');
    for k = 1:nConds
        bg(k).FaceColor = condColors(k,:);
    end

    ylabel('Mean dB SPL');
    xtickangle(45);
    ax = gca;
    ax.XGrid = "off"; % No vertical lines
    ax.YGrid = "on"; 
    title('Mean Sound Pressure Level by Event and Condition');

    hold on;
    for k = 1:nConds
        xpos = bg(k).XEndPoints;
        ytip = bg(k).YEndPoints;
        errs = errGrp(:,k)';
        mask = isfinite(ytip) & isfinite(errs);
        if any(mask)
            er = errorbar(xpos(mask), ytip(mask), errs(mask), errs(mask), ...
                'LineStyle', 'none', 'Color', [0 0 0], 'CapSize', 6, 'LineWidth', 1);
            uistack(er, 'bottom');
        end
    end

    legend(bg, strrep(conditionNames, '_', '\_'), 'Location', 'best');

    ylims2  = ylim;
    yrange2 = range(ylims2);
    ylim([ylims2(1), ylims2(2) + 0.15*yrange2]);
    hold off;
end