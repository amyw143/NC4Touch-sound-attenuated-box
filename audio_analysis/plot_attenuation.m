function plot_attenuation(eventIDs, attenuation, sigStars, cohensD)
% PLOT_ATTENUATION  Bar plot of dB attenuation per event (box_open - box_closed)
% with significance stars and Cohen's d effect size.
%
% INPUTS:
%   eventIDs    - cell array of event name strings
%   attenuation - vector of dB differences (box_open - box_closed)
%   sigStars    - cell array of significance strings (e.g. '***', 'n.s.')
%   cohensD     - vector of Cohen's d effect sizes

    x       = categorical(eventIDs);
    nEvents = numel(eventIDs);

    figure('Position', [100 100 900 500]);
    b = bar(x, attenuation);
    b.FaceColor = 'flat';
    for i = 1:nEvents
        if attenuation(i) > 0
            b.CData(i,:) = [1 0.6 0.2];
        else
            b.CData(i,:) = [0.2 0.6 1];
        end
    end

    ylabel('Attenuation (dB): box\_open - box\_closed');
    xtickangle(45);
    grid on;
    title('Sound Attenuation by Event: Box Open vs Box Closed');

    hold on;
    ylims  = ylim;
    yrange = range(ylims);
    for i = 1:nEvents
        ypos = attenuation(i) + sign(attenuation(i)) * 0.03 * yrange;
        text(i, ypos, sprintf('%.1f dB\n%s (d=%.1f)', attenuation(i), sigStars{i}, cohensD(i)), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment',   'bottom', ...
            'FontSize', 9);
    end
    ylim([ylims(1) - 0.1*yrange, ylims(2) + 0.22*yrange]);
    hold off;
end