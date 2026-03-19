%% BOXED CONDITIONS ANALYSIS SCRIPT
% Runs the full audio analysis pipeline on box-closed and box-open
% conditions, then produces a grouped bar comparison plot.
%
% To add more conditions, edit config.m only — this script runs automatically.
% =========================================================================

config;  % loads all paths and settings from config.m

%% -------------------- LOAD CALIBRATION --------------------
calData           = load(cfg.calibPath);
calibrationGain_G = calData.calibrationGain_G;
fprintf('[INFO] Calibration gain loaded: %.6f\n', calibrationGain_G);

%% -------------------- RUN PIPELINE PER CONDITION --------------------
allStats       = cell(1, numel(cfg.conditions));
allEventTiming = cell(1, numel(cfg.conditions));

for c = 1:numel(cfg.conditions)
    cond = cfg.conditions(c);
    fprintf('\n[INFO] Processing condition: %s\n', cond.name);

    % --- Load audio ---
    [y, fs] = audioread(cond.audioFile);
    fprintf('[INFO] Duration: %.2f s | Sample rate: %d Hz\n', length(y)/fs, fs);

    % --- Load and parse events ---
    events = clean_events(cond.eventFile);

    % --- Find all StartLoop timestamps ---
    T0 = parse_timestamp(startMatches(1).timestamp);
    startMatches = events(strcmp({events.event}, 'StartLoop'));
    if isempty(startMatches)
        error('No StartLoop found in %s', cond.eventFile);
    end

    % --- Extract event windows ---
    windows = extract_event_windows(events);
    fprintf('[INFO] Found %d trial(s).\n', numel(windows));

    for trial = 1:numel(windows)
        extract_audio(windows{trial}, trial, cond.audioFile, ...
            cond.audioStart, cond.extractedDir);
    end

    % --- Compute dB per event file ---
    audioFiles = dir(fullfile(cond.extractedDir, '*.wav'));
    nFiles     = numel(audioFiles);
    if nFiles == 0
        error('No .wav files found in %s', cond.extractedDir);
    end

    results = struct('fileName', cell(1,nFiles), 'level_dB', num2cell(nan(1,nFiles)));

    for f = 1:nFiles
        [yEv, ~] = audioread(fullfile(cond.extractedDir, audioFiles(f).name));
        yPa      = yEv .* calibrationGain_G;
        level_dB = patodB(yPa);

        results(f).fileName = audioFiles(f).name;
        results(f).level_dB = level_dB;
        fprintf('[INFO] %s: %.2f dB\n', audioFiles(f).name, level_dB);
    end

    % --- Group stats per event ---
    Tbl     = struct2table(results);
    eventID = regexp(Tbl.fileName, '^[^_]+', 'match', 'once');
    [g, eventList] = findgroups(eventID);

    meanPerEvent   = splitapply(@(x) 10*log10(mean(10.^(x/10), 'omitnan')), Tbl.level_dB, g);
    medianPerEvent = splitapply(@(x) median(x, 'omitnan'), Tbl.level_dB, g);
    stdPerEvent    = splitapply(@(x) std(x,    'omitnan'), Tbl.level_dB, g);
    countPerEvent  = splitapply(@numel,         Tbl.level_dB, g);

    eventStats = struct( ...
        'eventID',   cellstr(eventList), ...
        'mean_dB',   num2cell(meanPerEvent), ...
        'median_dB', num2cell(medianPerEvent), ...
        'std_dB',    num2cell(stdPerEvent), ...
        'nFiles',    num2cell(countPerEvent) ...
    );

    % Store raw per-trial dB values for per-event t-tests
    nGroups = max(g);
    for i = 1:nGroups
        eventStats(i).raw_dB = Tbl.level_dB(g == i);
    end

    % Store event timing relative to T0 for waveform/spectrogram plotting
    % Each entry: {eventName, tStart, tEnd} relative to trimmed audio start
    eventTiming = {};
    for trial = 1:numel(windows)
        trialWin = windows{trial};
        for k = 1:size(trialWin, 1)
            evName  = strtrim(string(trialWin(k,1)));
            tStart  = seconds(parse_timestamp(strtrim(string(trialWin(k,2)))) - T0);
            tEnd    = seconds(parse_timestamp(strtrim(string(trialWin(k,3)))) - T0);
            eventTiming{end+1} = {char(evName), tStart, tEnd};
        end
    end
    allEventTiming{c} = eventTiming;

    % --- Print results ---
    fprintf('\n[RESULTS] %s\n', cond.name);
    fprintf('%-20s %10s\n', 'Event', 'Mean dB');
    fprintf('%s\n', repmat('-', 1, 32));
    for i = 1:numel(eventStats)
        fprintf('%-20s %10.2f\n', eventStats(i).eventID, eventStats(i).mean_dB);
    end

    % --- Save ---
    save(cond.statsFile, 'eventStats');
    fprintf('[INFO] Saved: %s\n', cond.statsFile);

    allStats{c} = eventStats;
end

%% -------------------- COMPARISON PLOT --------------------
%% -------------------- COMPARISON PLOT --------------------
fprintf('\n[INFO] Generating comparison plot...\n');

condNames   = {cfg.conditions.name};
openIdx2    = find(strcmp(condNames, 'box_open'),        1);
closedIdx   = find(strcmp(condNames, 'box_closed'),       1);

T_closed = struct2table(allStats{closedIdx});
T_open   = struct2table(allStats{openIdx2});

nEvents     = numel(allStats{closedIdx});
eventIDs    = {allStats{closedIdx}.eventID};
attenuation = T_open.mean_dB - T_closed.mean_dB;

% --- Per-event paired t-test + Cohen's d (box_open vs box_closed) ---
pVals    = nan(nEvents, 1);
cohensD  = nan(nEvents, 1);
sigStars = cell(nEvents, 1);
for i = 1:nEvents
    raw_closed = allStats{closedIdx}(i).raw_dB;
    raw_open   = allStats{openIdx2}(i).raw_dB;
    [~, pVals(i)] = ttest(raw_open, raw_closed);
    d          = raw_open - raw_closed;
    cohensD(i) = mean(d) / std(d);
    if     isnan(pVals(i)),   sigStars{i} = 'n/a';
    elseif pVals(i) < 0.001,  sigStars{i} = '***';
    elseif pVals(i) < 0.01,   sigStars{i} = '**';
    elseif pVals(i) < 0.05,   sigStars{i} = '*';
    else,                     sigStars{i} = 'n.s.';
    end
end

% --- Print attenuation table ---
fprintf('\n[ATTENUATION] box_open vs box_closed\n');
fprintf('%-20s %10s %10s %10s %10s %6s\n', 'Event', 'Open dB', 'Closed dB', 'Delta dB', 'Cohen d', 'Sig');
fprintf('%s\n', repmat('-', 1, 70));
for i = 1:nEvents
    fprintf('%-20s %10.2f %10.2f %10.2f %10.2f %6s\n', ...
        eventIDs{i}, T_open.mean_dB(i), T_closed.mean_dB(i), attenuation(i), cohensD(i), sigStars{i});
end

plot_attenuation(eventIDs, attenuation, sigStars, cohensD);
allStatsTables = cellfun(@struct2table, allStats, 'UniformOutput', false);
plot_comparison(allStatsTables, condNames, sigStars);
plot_waveform(cfg, allEventTiming);
plot_spectrogram(cfg, allEventTiming);

fprintf('[DONE] Analysis complete.\n');