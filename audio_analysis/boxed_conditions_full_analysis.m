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

%% -------------------- SYNC CORRECTION (box-open only) --------------------
openIdx    = find(strcmp({cfg.conditions.name}, cfg.syncCondition), 1);
openCond   = cfg.conditions(openIdx);
openEvents = clean_events(openCond.eventFile);

openBuzzerMatch = openEvents(strcmp({openEvents.event}, 'Buzzer60') & strcmp({openEvents.data}, 'ON'));
openBuzzerT     = parse_timestamp(openBuzzerMatch(1).timestamp);

syncError = compute_audio_correction(openCond.audioFile, openCond.audioStart, openBuzzerT);
for c = 1:numel(cfg.conditions)
    cfg.conditions(c).audioStart = cfg.conditions(c).audioStart - seconds(syncError);
end

%% -------------------- RUN PIPELINE PER CONDITION --------------------
allStats = cell(1, numel(cfg.conditions));

for c = 1:numel(cfg.conditions)
    cond = cfg.conditions(c);
    fprintf('\n[INFO] Processing condition: %s\n', cond.name);

    % --- Load audio ---
    [y, fs] = audioread(cond.audioFile);
    fprintf('[INFO] Duration: %.2f s | Sample rate: %d Hz\n', length(y)/fs, fs);

    % --- Load and parse events ---
    events = clean_events(cond.eventFile);

    % --- Find all StartLoop timestamps ---
    startMatches = events(strcmp({events.event}, 'StartLoop'));
    if isempty(startMatches)
        error('No StartLoop found in %s', cond.eventFile);
    end

    % --- Trim to first StartLoop ---
    T0         = parse_timestamp(startMatches(1).timestamp);
    offsetTime = seconds(T0 - cond.audioStart);
    if offsetTime < 0
        error('Event occurs before audio start for condition: %s', cond.name);
    end

    nRemove = round(offsetTime * fs);
    if nRemove >= size(y,1)
        error('Offset longer than audio duration for condition: %s', cond.name);
    end

    yTrimmed = y(nRemove+1:end, :);
    yTrimmed = bandpass_filter_audio(yTrimmed, cfg.audioBandFilter, fs);
    audiowrite(cond.trimmedFile, yTrimmed, fs);
    fprintf('[INFO] Trimmed %.3f s. Wrote: %s\n', offsetTime, cond.trimmedFile);

    % --- Extract event windows ---
    windows = extract_event_windows(events);
    fprintf('[INFO] Found %d trial(s).\n', numel(windows));

    for trial = 1:numel(windows)
        extract_audio(windows{trial}, trial, cond.trimmedFile, ...
            T0, cond.extractedDir);
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

%% -------------------- WAVEFORMS AND SPECTROGRAMS --------------------
plot_waveform(allStats, cfg);
plot_spectrogram(allStats, cfg);

%% -------------------- COMPARISON PLOTS --------------------
fprintf('\n[INFO] Generating comparison plots...\n');
 
plot_attenuation(eventIDs, attenuation, sigStars, cohensD);
plot_comparison(T1, T2, {cfg.conditions.name}, sigStars);
 
fprintf('[DONE] Analysis complete.\n');