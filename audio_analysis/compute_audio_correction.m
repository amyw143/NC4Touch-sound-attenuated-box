function syncError = compute_audio_correction(audioFile, audioStart, buzzerT, varargin)
% COMPUTE_AUDIO_CORRECTION  Auto-detects Buzzer60 onset in audio via RMS
% envelope and returns the sync error in seconds.
%
% INPUTS:
%   audioFile  - path to the RAW (untrimmed) audio file
%   audioStart - datetime, manually entered cond.audioStart
%   buzzerT    - datetime, first Buzzer60 ON timestamp
%
% OPTIONAL NAME-VALUE PAIRS:
%   'plot'         - true/false (default: false)
%   'rmsWindowSec' - RMS window size in seconds (default: 0.05)
%   'thresholdDB'  - dB rise above baseline to detect onset (default: 3.0)
%   'baselineSec'  - seconds at start used to estimate baseline (default: 5.0)
%   'searchMargin' - search window either side of expected onset (default: 5.0)
%
% OUTPUT:
%   syncError  - seconds to ADD to audioStart to correct sync
%                i.e. correctedStart = audioStart + seconds(syncError)

    p = inputParser;
    addParameter(p, 'plot',         false);
    addParameter(p, 'rmsWindowSec', 0.05);
    addParameter(p, 'thresholdDB',  3.0);
    addParameter(p, 'baselineSec',  5.0);
    addParameter(p, 'searchMargin', 5.0);
    parse(p, varargin{:});
    doPlot       = p.Results.plot;
    rmsWindowSec = p.Results.rmsWindowSec;
    threshDB     = p.Results.thresholdDB;
    baselineSec  = p.Results.baselineSec;
    searchMargin = p.Results.searchMargin;

    % --- Load audio ---
    [y, fs] = audioread(audioFile);
    if size(y, 2) > 1, y = mean(y, 2); end
    fprintf('[INFO] Loaded audio: %s (%.2f s @ %d Hz)\n', audioFile, length(y)/fs, fs);

    % --- Compute RMS envelope ---
    winSamples = round(rmsWindowSec * fs);
    hopSamples = round(winSamples / 2);
    nFrames    = floor((length(y) - winSamples) / hopSamples) + 1;
    rmsEnv     = zeros(nFrames, 1);
    timeAxis   = zeros(nFrames, 1);

    for i = 1:nFrames
        idx         = (i-1)*hopSamples + (1:winSamples);
        rmsEnv(i)   = sqrt(mean(y(idx).^2));
        timeAxis(i) = ((i-1)*hopSamples + winSamples/2) / fs;
    end

    rmsDB = 20 * log10(rmsEnv + eps);

    % --- Estimate baseline from start of file ---
    baselineFrames = timeAxis <= baselineSec;
    if sum(baselineFrames) < 5
        warning('Not enough baseline frames — using first 10 frames');
        baselineFrames = false(nFrames, 1);
        baselineFrames(1:min(10, nFrames)) = true;
    end
    baselineDB = median(rmsDB(baselineFrames));
    fprintf('[INFO] Baseline dB (first %.1f s): %.2f dB\n', baselineSec, baselineDB);

    % --- Compute expected Buzzer position in raw audio ---
    expectedBuzzerRaw = seconds(buzzerT - audioStart);
    fprintf('[INFO] Expected Buzzer onset in raw audio: %.4f s\n', expectedBuzzerRaw);

    % --- Search for onset near expected time ---
    searchMask = timeAxis >= (expectedBuzzerRaw - searchMargin) & ...
                 timeAxis <= (expectedBuzzerRaw + searchMargin);

    if sum(searchMask) < 3
        error(['Search window [%.2f, %.2f] s is out of audio range (%.2f s). ' ...
               'Check audioStart and JSON timestamps.'], ...
               expectedBuzzerRaw - searchMargin, ...
               expectedBuzzerRaw + searchMargin, ...
               length(y)/fs);
    end

    searchDB   = rmsDB(searchMask);
    searchTime = timeAxis(searchMask);
    onsetIdx   = find(searchDB >= (baselineDB + threshDB), 1, 'first');

    if isempty(onsetIdx)
        error(['No Buzzer onset detected within %.1f s of expected position. ' ...
               'Try lowering ''thresholdDB'' (currently %.1f dB) or increasing ''searchMargin''.'], ...
               searchMargin, threshDB);
    end

    detectedBuzzerRaw = searchTime(onsetIdx);
    fprintf('[INFO] Detected Buzzer onset in raw audio: %.4f s\n', detectedBuzzerRaw);

    % --- Sync error ---
    syncError = detectedBuzzerRaw - expectedBuzzerRaw;

    fprintf('\n[SYNC CORRECTION REPORT]\n');
    fprintf('  Expected Buzzer in raw: %.4f s\n', expectedBuzzerRaw);
    fprintf('  Detected Buzzer in raw: %.4f s\n', detectedBuzzerRaw);
    fprintf('  Sync error:             %.4f s\n\n', syncError);

    % --- Optional plot ---
    if doPlot
        figure('Name', 'Buzzer Onset Detection', 'Position', [100 100 1000 400]);
        plot(timeAxis, rmsDB, 'b-', 'LineWidth', 0.8); hold on;
        yline(baselineDB + threshDB, 'k--', 'Threshold');
        xline(expectedBuzzerRaw,  'g-', 'Expected', 'LineWidth', 1.5);
        xline(detectedBuzzerRaw,  'r-', 'Detected', 'LineWidth', 1.5);
        xlim([expectedBuzzerRaw - searchMargin, expectedBuzzerRaw + searchMargin]);
        xlabel('Time in raw audio (s)');
        ylabel('RMS dB');
        title(sprintf('Buzzer Onset Detection  |  Sync error: %.4f s', syncError));
        legend('RMS envelope', 'Threshold', 'Expected onset', 'Detected onset');
        grid on;
    end
end