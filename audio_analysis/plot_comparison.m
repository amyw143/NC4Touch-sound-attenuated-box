function plot_comparison(allStatsTables, conditionNames, sigStars)
% PLOT_COMPARISON  Grouped bar plot of absolute mean dB SPL per event and
% condition, with error bars and significance stars.
%
% INPUTS:
%   allStatsTables - struct2table output of stats for all conditions
%   conditionNames - cell array of condition name strings (e.g. {'box_closed','box_open'})
%   sigStars       - cell array of significance strings per event

    T1     = allStatsTables{1};
    x      = categorical(T1.eventID);
    nConds = numel(allStatsTables);
    yGrp   = cell2mat(cellfun(@(T) T.mean_dB, allStatsTables, 'UniformOutput', false));
    errGrp = cell2mat(cellfun(@(T) T.std_dB,  allStatsTables, 'UniformOutput', false));

    figure('Position', [100 100 900 500]);
    bg = bar(x, yGrp, 'grouped');
    cmap = colormap('turbo');
    for k = 1:nConds
       bg(k).FaceColor = cmap(round((k-1)*(255/(nConds-1)) + 1), :);
    end

    ylabel('Mean dB SPL');
    xtickangle(45);
    grid on;
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
    nEvents = numel(sigStars);
    for i = 1:nEvents
        xmid = mean([bg(1).XEndPoints(i), bg(2).XEndPoints(i)]);
        ytop = max(bg(1).YEndPoints(i) + errGrp(i,1), bg(2).YEndPoints(i) + errGrp(i,2)) + 0.03*yrange2;
        text(xmid, ytop, sigStars{i}, ...
            'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    end
    ylim([ylims2(1), ylims2(2) + 0.15*yrange2]);
    hold off;
end