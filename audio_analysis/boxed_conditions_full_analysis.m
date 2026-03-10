%% BOXED CONDITIONS ANALYSIS SCRIPT
% Runs the full audio analysis pipeline on box-closed and box-open
% conditions, then produces a grouped bar comparison plot.
%
% To add more conditions, add an entry to the CONDITIONS struct below.
% All other code runs automatically.
% =========================================================================

%% -------------------- CONFIG (edit here only) --------------------
% --- Conditions ---
conditions(1).name         = 'box_closed';
conditions(1).audioFile    = '/Users/amywong/Documents/MATLAB/nc4touch-data/data_march/phase_2_2.wav';
conditions(1).audioStart   = datetime('2026-03-09 14:43:21.100', 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
conditions(1).eventFile    = '/Users/amywong/Documents/MATLAB/nc4touch-data/data_march/phase_2_2.json';

conditions(2).name         = 'box_open';
conditions(2).audioFile    = '/Users/amywong/Documents/MATLAB/nc4touch-data/data_march/phase_2b_2.wav';
conditions(2).audioStart   = datetime('2026-03-09 14:34:58.100', 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
conditions(2).eventFile    = '/Users/amywong/Documents/MATLAB/nc4touch-data/data_march/phase_2b_2.json';

% --- Shared settings ---
calibPath       = '/Users/amywong/Documents/MATLAB/nc4touch-data/audio_calibration/calibration_params.mat';
baseDir         = '/Users/amywong/Documents/MATLAB/nc4touch-data/analysis';
audioBandFilter = [200, 90000];   % Hz
baselineMean    = 69.40;          % dB SPL — from baseline recording

% =========================================================================
%% -------------------- LOAD CALIBRATION --------------------
calData           = load(calibPath);
calibrationGain_G = calData.calibrationGain_G;
fprintf('[INFO] Calibration gain loaded: %.6f\n', calibrationGain_G);

%% -------------------- RUN PIPELINE PER CONDITION --------------------
allStats = cell(1, numel(conditions));

for c = 1:numel(conditions)
    cond = conditions(c);
    fprintf('\n[INFO] Processing condition: %s\n', cond.name);

    % --- Paths ---
    trimmedFile  = fullfile(baseDir, sprintf('trimmed_%s.wav',    cond.name));
    extractedDir = fullfile(baseDir, sprintf('extracted_%s',      cond.name));
    statsFile    = fullfile(baseDir, sprintf('%s_eventStats.mat', cond.name));

    % --- Load audio ---
    [y, fs] = audioread(cond.audioFile);
    fprintf('[INFO] Duration: %.2f s | Sample rate: %d Hz\n', length(y)/fs, fs);

    % --- Load and parse events ---
    events = clean_events(cond.eventFile);

    % --- Find all StartLoop timestamps ---
    idx = strcmp({events.event}, 'StartLoop');
    if ~any(idx)
        error('No StartLoop found in %s', cond.eventFile);
    end
    tsStr = {events(idx).timestamp};

    % --- Trim to first StartLoop ---
    T0         = parse_timestamp(tsStr{1});
    offsetTime = seconds(T0 - cond.audioStart);
    if offsetTime < 0
        error('Event occurs before audio start for condition: %s', cond.name);
    end

    nRemove = round(offsetTime * fs);
    if nRemove >= size(y,1)
        error('Offset longer than audio duration for condition: %s', cond.name);
    end

    yTrimmed = y(nRemove+1:end, :);
    yTrimmed = bandpass_filter_audio(yTrimmed, audioBandFilter, fs);
    audiowrite(trimmedFile, yTrimmed, fs);
    fprintf('[INFO] Trimmed %.3f s. Wrote: %s\n', offsetTime, trimmedFile);

    % --- Extract event windows ---
    windows = extract_event_windows(events);
    fprintf('[INFO] Found %d trial(s).\n', numel(windows));

    for trial = 1:numel(windows)
        T_trial = parse_timestamp(tsStr{trial});
        extract_audio(windows{trial}, trial, trimmedFile, T_trial, extractedDir);
    end

    % --- Compute dB per event file ---
    audioFiles = dir(fullfile(extractedDir, '*.wav'));
    nFiles     = numel(audioFiles);
    if nFiles == 0
        error('No .wav files found in %s', extractedDir);
    end

    results = struct('fileName', cell(1,nFiles), 'level_dB', num2cell(nan(1,nFiles)));

    for f = 1:nFiles
        [yEv, fsEv] = audioread(fullfile(extractedDir, audioFiles(f).name));
        yPa         = yEv .* calibrationGain_G;
        level_dB    = 10 * log10(mean(yPa.^2) / (20e-6)^2);

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

    % --- Baseline correction ---
    for i = 1:numel(eventStats)
        eventStats(i).mean_dB_corrected = eventStats(i).mean_dB - baselineMean;
    end

    % --- Print results ---
    fprintf('\n[RESULTS] %s (baseline = %.2f dB)\n', cond.name, baselineMean);
    fprintf('%-20s %10s %10s\n', 'Event', 'Abs dB', 'Rel dB');
    fprintf('%s\n', repmat('-', 1, 42));
    for i = 1:numel(eventStats)
        fprintf('%-20s %10.2f %10.2f\n', ...
            eventStats(i).eventID, ...
            eventStats(i).mean_dB, ...
            eventStats(i).mean_dB_corrected);
    end

    % --- Save ---
    save(statsFile, 'eventStats');
    fprintf('[INFO] Saved: %s\n', statsFile);

    allStats{c} = eventStats;
end

%% -------------------- COMPARISON PLOT --------------------
fprintf('\n[INFO] Generating comparison plot...\n');

T1  = struct2table(allStats{1});
T2  = struct2table(allStats{2});

% Align events — use condition 1 event list as reference
x   = categorical(T1.eventID);
y   = [T1.mean_dB - baselineMean, T2.mean_dB - baselineMean];   % Nx2, relative dB
err = [T1.std_dB, T2.std_dB];                                    % Nx2

% Paired t-test across matched events
[~, p] = ttest(T2.mean_dB, T1.mean_dB);
if     isnan(p),   sigLabel = 'n/a';
elseif p < 0.001,  sigLabel = '***';
elseif p < 0.01,   sigLabel = '**';
elseif p < 0.05,   sigLabel = '*';
else,              sigLabel = 'n.s.';
end

% --- Plot ---
figure('Position', [100 100 900 500]);
b = bar(x, y, 'grouped');
b(1).FaceColor = [0.2 0.6 1];   % blue  — box-closed
b(2).FaceColor = [1 0.6 0.2];   % orange — box-open

ylabel('Mean dB SPL (relative to baseline)');
xtickangle(45);
grid on;
title('Change in Mean Sound Pressure Level by Event (dB rel. baseline)');

% Error bars
hold on;
for k = 1:numel(b)
    xpos = b(k).XEndPoints;
    ytip = b(k).YEndPoints;
    errs = err(:,k)';
    mask = isfinite(ytip) & isfinite(errs);
    if any(mask)
        er = errorbar(xpos(mask), ytip(mask), errs(mask), errs(mask), ...
            'LineStyle', 'none', 'Color', [0 0 0], 'CapSize', 8, 'LineWidth', 1);
        uistack(er, 'bottom');
    end
end

% Numeric labels above bars
ylims  = ylim;
yrange = range(ylims);
labelGapFrac = 0.02;
for k = 1:numel(b)
    xtips = b(k).XEndPoints;
    ytips = b(k).YEndPoints;
    vals  = b(k).YData;
    errs  = err(:,k)';
    mask  = isfinite(vals) & isfinite(errs);
    if any(mask)
        ylabels = ytips(mask) + errs(mask) + labelGapFrac * yrange;
        text(xtips(mask), ylabels, string(round(vals(mask), 1)), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment',   'bottom', ...
            'FontSize', 9);
    end
end

legend(b, {"box-closed", "box-open"}, 'Location', 'best');

% p-value annotation
if ~isnan(p), pstr = num2str(round(p,3));
else,         pstr = 'NaN';
end
ylim([ylims(1), ylims(2) + 0.14 * yrange]);
text(0.5, 0.98, sprintf('Paired t-test: p=%s %s', pstr, sigLabel), ...
    'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
hold off;

fprintf('[DONE] Analysis complete.\n');

%% =========================================================================
%% HELPER FUNCTIONS
%% =========================================================================

function clean_evts = clean_events(eventFile)
% Reads NC4Touch .json event file and parses into struct array
    raw      = fileread(eventFile);
    rawClean = regexprep(raw,      '^\s*#.*\n',                '', 'lineanchors');
    rawClean = regexprep(rawClean, '^\s*\{"header":.*?\}\s*',  '');
    rawClean = regexprep(rawClean, '^\s*\}\s*',                '');
    rawClean = regexprep(rawClean, '}\s*{',                    '},{');
    rawClean = ['[' rawClean ']'];
    clean_evts = jsondecode(rawClean);
end

function T = parse_timestamp(raw)
% Converts YYYYMMDD_HHMMSS_ffffff string to datetime
    raw   = string(raw);
    parts = split(raw, "_");
    if numel(parts) < 3
        error('Unexpected timestamp format: %s', raw);
    end
    datePart = parts(1); timePart = parts(2); fracPart = parts(3);

    yyyy = extractBetween(datePart,1,4);
    mm   = extractBetween(datePart,5,6);
    dd   = extractBetween(datePart,7,8);
    HH   = extractBetween(timePart,1,2);
    MM   = extractBetween(timePart,3,4);
    SS   = extractBetween(timePart,5,6);

    ms = fracPart;
    if strlength(ms) >= 3, ms = extractBetween(ms,1,3);
    else, ms = ms + repmat("0", 1, 3 - strlength(ms));
    end

    tStr = yyyy+"-"+mm+"-"+dd+" "+HH+":"+MM+":"+SS+"."+ms;
    T    = datetime(tStr, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
end

function event_windows = extract_event_windows(events)
% Extracts per-loop event windows as cell array of Mx3 string arrays
    if isscalar(events) && (iscell(events(1).timestamp) || isstring(events(1).timestamp))
        S = string(events(1).event(:)).';
        D = string(events(1).data(:)).';
        T = string(events(1).timestamp(:)).';
    else
        S = string({events.event});
        D = string({events.data});
        T = string({events.timestamp});
    end

    startIdx = find(S == "StartLoop");
    endIdx   = find(S == "EndLoop");

    if numel(startIdx) ~= numel(endIdx) || any(startIdx >= endIdx)
        error('Mismatched StartLoop/EndLoop events or ordering.');
    end

    numLoops      = numel(startIdx);
    event_windows = cell(1, numLoops);

    for k = 1:numLoops
        i0       = startIdx(k);
        i1       = endIdx(k);
        idxRange = (i0+1):(i1-1);

        if numel(idxRange) < 2
            event_windows{k} = strings(0,3);
            continue
        end

        Sr = reshape(string(S(idxRange)), [], 1);
        Dr = reshape(string(D(idxRange)), [], 1);
        Tr = reshape(string(T(idxRange)), [], 1);

        sameEvent     = Sr(1:end-1) == Sr(2:end);
        diffData      = Dr(1:end-1) ~= Dr(2:end);
        idxPairsLocal = find(sameEvent & diffData);

        if isempty(idxPairsLocal)
            event_windows{k} = strings(0,3);
            continue
        end

        event_windows{k} = [Sr(idxPairsLocal), Tr(idxPairsLocal), Tr(idxPairsLocal+1)];
    end
end

function extract_audio(trialArray, trialNum, audioFile, fileStartTime, outputFolder)
% Extracts per-event audio segments and saves to outputFolder
    if ~isfolder(outputFolder), mkdir(outputFolder); end

    info         = audioinfo(audioFile);
    fs           = info.SampleRate;
    durationFile = info.Duration;

    for k = 1:size(trialArray,1)
        eventName  = strtrim(string(trialArray(k,1)));
        rawStart   = strtrim(string(trialArray(k,2)));
        rawEnd     = strtrim(string(trialArray(k,3)));

        try
            tStartDT = datetime(parse_timestamp(rawStart));
            tEndDT   = datetime(parse_timestamp(rawEnd));
        catch
            warning('Failed to parse timestamps for %s (trial %d)', eventName, trialNum);
            continue
        end

        t0 = max(0,            seconds(tStartDT - fileStartTime));
        endBuffer_s = 0.4;  % trim 400ms from end to avoid next-event bleed
        t1 = min(durationFile, seconds(tEndDT - fileStartTime) - endBuffer_s);

        if t1 <= t0
            warning('Event %s out of range or zero length', eventName);
            continue
        end

        startSample = floor(t0*fs) + 1;
        endSample   = min(ceil(t1*fs), ceil(durationFile*fs));
        ySeg        = audioread(audioFile, [startSample endSample]);

        outName = sprintf('%s_trial%d.wav', regexprep(eventName,'[^\w-]','_'), trialNum);
        audiowrite(fullfile(outputFolder, outName), ySeg, fs);
    end
    fprintf('[INFO] Trial %d: audio segments saved.\n', trialNum);
end

function audioFiltered = bandpass_filter_audio(audioData, audioBandFilter, audioFs)
% Applies bandpass filter to audio signal
    bpFilt = designfilt('bandpassiir', ...
        'FilterOrder',         8, ...
        'HalfPowerFrequency1', audioBandFilter(1), ...
        'HalfPowerFrequency2', audioBandFilter(2), ...
        'SampleRate',          audioFs);
    audioFiltered = filtfilt(bpFilt, audioData);
    fprintf('[INFO] Applied bandpass filter: %.0f-%.0f Hz\n', ...
        audioBandFilter(1), audioBandFilter(2));
end