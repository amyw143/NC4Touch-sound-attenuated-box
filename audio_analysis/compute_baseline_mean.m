%% Baseline SPL Analysis — Single File
% -------------------------------------------------------------------------
% USER SETTINGS — set the filename in config.m Section B
% To switch between files, change baselineFile in config.m
% -------------------------------------------------------------------------
config;

% -------------------------------------------------------------------------
% LOAD CALIBRATION
% -------------------------------------------------------------------------
data = load(cfg.calibPath);
calibrationGain_G = data.calibrationGain_G;
fprintf('[INFO] Calibration gain loaded: %.6f\n', calibrationGain_G);

% -------------------------------------------------------------------------
% LOAD AND PROCESS AUDIO
% -------------------------------------------------------------------------
[y_raw, fs] = audioread(cfg.baselineFile);
fprintf('[INFO] Loaded: %s\n', cfg.baselineFile);
fprintf('[INFO] Duration: %.2f s | Sample rate: %d Hz\n', length(y_raw)/fs, fs);

% Bandpass filter
y_filtered = bandpass_filter_audio(y_raw, cfg.audioBandFilter, fs);

% Compare RMS before and after
fprintf('RMS before filter: %.6f\n', rms(y_raw));
fprintf('RMS after filter:  %.6f\n', rms(y_filtered));

% Energy removed by filter
y_removed = y_raw - y_filtered;
fprintf('RMS of removed content: %.6f\n', rms(y_removed));

% Apply calibration
yPa_raw      = y_raw      .* calibrationGain_G;
yPa_filtered = y_filtered .* calibrationGain_G;

% Compute dB before and after filter
dB_raw      = 10 * log10(mean(yPa_raw.^2)      / (20e-6)^2);
dB_filtered = 10 * log10(mean(yPa_filtered.^2) / (20e-6)^2);

fprintf('dB before filter: %.2f\n', dB_raw);
fprintf('dB after filter:  %.2f\n', dB_filtered);
fprintf('[INFO] Mean SPL: %.2f dB\n', dB_filtered);

% -------------------------------------------------------------------------
% HELPER FUNCTIONS
% -------------------------------------------------------------------------
function audioPa = apply_audio_calibration(audioData, calibrationGain_G)
    audioPa = audioData .* calibrationGain_G;
end

function audioFiltered = bandpass_filter_audio(audioData, audioBandFilter, audioFs)
    bpFilt = designfilt('bandpassiir', ...
        'FilterOrder',         8, ...
        'HalfPowerFrequency1', audioBandFilter(1), ...
        'HalfPowerFrequency2', audioBandFilter(2), ...
        'SampleRate',          audioFs);
    audioFiltered = filtfilt(bpFilt, audioData);
    fprintf('[INFO] Applied bandpass filter: %.0f-%.0f Hz\n', ...
        audioBandFilter(1), audioBandFilter(2));
end