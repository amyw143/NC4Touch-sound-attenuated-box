%% Phase 2 Test Script
% Load audio, calibration, and events for one trial

%% ------------------------
% Paths and parameters
audioFile      = '/Users/amywong/Documents/MATLAB/nc4touch-data/phase_2b/phase_2b_021826_1.wav';
audioStartTime = datetime('2026-02-18 13:51:06.100','InputFormat','yyyy-MM-dd HH:mm:ss.SSS');
eventFile      = '/Users/amywong/Documents/MATLAB/nc4touch-data/phase_2b/events_1.json';
outFile        = 'trimmed.wav';
calibPath      = '/Users/amywong/Documents/MATLAB/nc4touch-data/audio_calibration/calibration_params.mat';
fs             = 192000;  % sample rate
eventDuration  = 10;      % seconds per event
Baseline_mean = "73.17";

% Load the audio file for processing
[y, fs] = audioread(audioFile);

%% -------------------- Load and clean JSON events --------------------
raw = fileread(eventFile);

% Remove comment lines starting with #
rawClean = regexprep(raw, '^\s*#.*\n', '', 'lineanchors');

% Remove initial header object
rawClean = regexprep(rawClean, '^\s*\{"header":.*?\}\s*', '');
rawClean = regexprep(rawClean, '^\s*\}\s*', '');

% Add commas between consecutive objects
rawClean = regexprep(rawClean, '}\s*{', '},{');

% Wrap in brackets to form valid JSON array
rawClean = ['[' rawClean ']'];

% Decode JSON into struct array
events = jsondecode(rawClean);

%% -------------------- Use StartLoop to compute offset time --------------------
idx = strcmp({events.event}, 'StartLoop'); 
if ~any(idx)
    error('No StartLoop event found.'); 
end 

tsStr = {events(idx).timestamp}; 
% Select only the first StartLoop event for T0
stloop = tsStr(:,1);
start_time = clean_timestamp(stloop);
% Convert the stloop value into a form compatible with datetime()
T = datetime(start_time, 'InputFormat', "yyyy-MM-dd HH:mm:ss.SSS");

% Calculate the offset time in seconds from the audio start time
offsetTime = seconds(T - audioStartTime);

if offsetTime < 0 
    error('Event occurs before the audio file starts. Cannot trim backward.')
end 

% Samples to remove
nRemove = round(offsetTime * fs);

if nRemove >= size(y,1)
    error('Offset is longer than audio duration. No audio remains after trimming.');
end

% Trim and write
yTrimmed = y(nRemove+1:end, :);
audiowrite(outFile, yTrimmed, fs);

fprintf('Trimmed %d samples (%.3f s). Wrote %s\n', nRemove, offsetTime, outFile);

%% -------------------- Extract audio from event windows from trimmed.wav --------------------
windows = extract_event_windows(events);

for trial = 1:numel(windows)
    trialArray = windows{trial};                 % 6x3 string array
    audioFile   = "/Users/amywong/Documents/MATLAB/trimmed.wav";             % e.g., 'trial1.wav'
    audioOrigin = T;           % datetime of sample 1 in the file
    extract_audio(trialArray, trial, audioFile, audioOrigin);
end

%% -------------------- Callibrate audio from event windows --------------------
% Apply audio calibration to every event window, find mean dB level for
% each event. 

% Load calibration 
data = load(calibPath);
calibrationGain_G = data.calibrationGain_G;
fprintf('[INFO] Calibration gain loaded: %.6f\n', calibrationGain_G);

extracted_event_audio_2b = "/Users/amywong/Documents/MATLAB/nc4touch-data/analysis/extracted_event_audio_2b";
audioFiles = dir(fullfile(extracted_event_audio_2b, '*.wav'));
phase2b_dB_all = [];

for f = 1:length(audioFiles)
    filePath = fullfile(extracted_event_audio_2b, audioFiles(f).name); 
    [y, fs] = audioread(filePath);

    % Apply calibration 
    yPa = apply_audio_calibration(y, calibrationGain_G);
    
    % Compute dB envelope
    yDB = compute_audio_dB_envelope(yPa, fs);

    % Store mean SPL for this file
    phase2b_dB_all(f) = mean(yDB);

    fprintf('[INFO] %s: %.2f dB\n', ...
        audioFiles(f).name, phase2b_dB_all(f));
end

%% -------------------- Helper functions --------------------

function clean_time = clean_timestamp(event)
% Converts timestamp of form YYYYMMDD_HHMMSS_ffffff (microseconds) into
% "yyyy-MM-dd HH:mm:ss.SSS" (milliseconds) as a string scalar.
clean_time = "";  % default

% Normalize input to a string scalar
if iscell(event)
    raw = event{1};
else
    raw = event;
end
raw = string(raw);          % string scalar or 1x1 string array
if isempty(raw)
    return
end
% split into parts
parts = split(raw, "_");    % ["20260218" "135115" "673236"]
if numel(parts) < 3
    error('Unexpected timestamp format. Expected "YYYYMMDD_HHMMSS_ffffff".');
end

datePart = parts(1);        % "20260218"
timePart = parts(2);        % "135115"
fracPart = parts(3);        % "673236"

% Build formatted pieces
yyyy = extractBetween(datePart,1,4);
mm   = extractBetween(datePart,5,6);
dd   = extractBetween(datePart,7,8);

HH = extractBetween(timePart,1,2);
MM = extractBetween(timePart,3,4);
SS = extractBetween(timePart,5,6);

% Convert microseconds to milliseconds (take first 3 digits, pad if needed)
ms = fracPart;
if strlength(ms) >= 3
    ms = extractBetween(ms,1,3);
else
    ms = ms + repmat("0", 1, 3 - strlength(ms)); % pad short fractions
end

% Compose final string: "yyyy-MM-dd HH:mm:ss.SSS"
clean_time = yyyy + "-" + mm + "-" + dd + " " + HH + ":" + MM + ":" + SS + "." + ms;
end

function event_windows = extract_event_windows(events)
% EXTRACT_EVENT_WINDOWS  Extract per-loop event windows.
%  event_windows = EXTRACT_EVENT_WINDOWS(events)
%  Input:
%    events - struct (1xN) with fields timestamp, event, data
%  Output:
%    event_windows - 1xnumLoops cell; each cell is an Mx3 string array:
%                    columns = [EventName, StartTimestamp, EndTimestamp]

% normalize to row string arrays
if isscalar(events) && (iscell(events(1).timestamp) || isstring(events(1).timestamp))
    S = string(events(1).event(:)).';
    D = string(events(1).data(:)).';
    T = string(events(1).timestamp(:)).';
else
    S = string({events.event});
    D = string({events.data});
    T = string({events.timestamp});
end

% find loop markers
startIdx = find(S == "StartLoop");
endIdx   = find(S == "EndLoop");

% validate loops
if numel(startIdx) ~= numel(endIdx) || any(startIdx >= endIdx)
    error("Mismatched StartLoop/EndLoop events or ordering.");
end

numLoops = numel(startIdx);
event_windows = cell(1, numLoops);

for k = 1:numLoops
    i0 = startIdx(k);
    i1 = endIdx(k);
    idxRange = (i0+1):(i1-1);  % events inside loop (exclusive of markers)

    if numel(idxRange) < 2
        % fewer than two events → no consecutive pair possible
        event_windows{k} = strings(0,3);   % empty Mx3 string array
        continue
    end

    % ensure column string arrays for subarrays
    Sr = reshape(string(S(idxRange)), [], 1);
    Dr = reshape(string(D(idxRange)), [], 1);
    Tr = reshape(string(T(idxRange)), [], 1);

    % find consecutive pairs where event name is the same and data differs
    sameEvent = Sr(1:end-1) == Sr(2:end);
    diffData  = Dr(1:end-1) ~= Dr(2:end);
    idxPairsLocal = find(sameEvent & diffData);

    if isempty(idxPairsLocal)
        event_windows{k} = strings(0,3);
        continue
    end

    % build Mx3 string array: each is Mx1 column, concatenation => Mx3
    names  = Sr(idxPairsLocal);         % Mx1
    starts = Tr(idxPairsLocal);         % Mx1 (start timestamps)
    ends   = Tr(idxPairsLocal + 1);     % Mx1 (end timestamps)

    event_windows{k} = [names, starts, ends];   % Mx3 string array
end
end

function extract_audio(trialArray, trialNum, audioFile, fileStartTime)
% trialArray : 6x3 string array, columns = {event, t_start, t_end}
% trialNum   : integer trial index (used for output names)
% audioFile  : string scalar or char to the audio file for this trial
% fileStartTime : datetime scalar indicating audio's absolute start time.
%                 If empty, timestamps are treated as durations (seconds).

outputFolder = fullfile(pwd, 'extracted_event_audio_2b');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

info = audioinfo(audioFile);
fs = info.SampleRate;
durationFile = info.Duration;
savedCount = 0;

for k = 1:size(trialArray,1)
    eventName = strtrim(string(trialArray(k,1)));
    rawStart  = strtrim(string(trialArray(k,2)));
    rawEnd    = strtrim(string(trialArray(k,3)));

    % Clean timestamps
    cleanStart = clean_timestamp(rawStart);
    cleanEnd   = clean_timestamp(rawEnd);
    if cleanStart == "" || cleanEnd == ""
        warning('Skipping event %s in trial %d: bad timestamp', eventName, trialNum);
        continue
    end

    % Parse as datetime
    try
        tStartDT = datetime(cleanStart, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
        tEndDT   = datetime(cleanEnd,   'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
    catch
        warning('Failed to parse cleaned timestamps for %s (trial %d)', eventName, trialNum);
        continue
    end

    % Compute offsets from audio origin
    t0 = seconds(tStartDT - fileStartTime);
    t1 = seconds(tEndDT   - fileStartTime);

    % If your trimmed.wav is already aligned so event start == audioOrigin,
    % then audioOrigin should be that event start; t0 will be ~0 for that event.

    % Clamp and validate
    t0 = max(0, t0);
    t1 = min(durationFile, t1);
    if t1 <= t0
        warning('Event %s out of range or zero length', eventName); continue
    end

    startSample = floor(t0*fs) + 1;
    endSample   = min(ceil(t1*fs), ceil(durationFile*fs));

    ySeg = audioread(audioFile, [startSample endSample]);

    outName = sprintf('%s_trial%d.wav', regexprep(eventName,'[^\w-]','_'), trialNum);
    outPath = fullfile(outputFolder, outName);  
    audiowrite(outPath, ySeg, fs);
end
disp('All audio files saved.');
end

function audioPa = apply_audio_calibration(audioData, calibrationGain_G)
% Takes in single audio data file and applies callibration gain, converting
% to Pascals. 
    ref_Pa = 20e-6;
    audioPa = audioData .* calibrationGain_G .* ref_Pa;
end

function audioDB = compute_audio_dB_envelope(audioPa, audioFs)
% Converts audio Pascals into dB using audioFs. 
    rmsWindow_ms = 20;
    ref_Pa = 20e-6;

    winSamples = round(audioFs * rmsWindow_ms / 1000);
    rmsEnvelope = sqrt(movmean(audioPa.^2, winSamples));

    audioDB = 20 * log10(rmsEnvelope / ref_Pa);
end