% Load both files
[y_on,  fs_on]  = audioread('/Users/amywong/Documents/MATLAB/nc4touch-data/data_march/baseline/baseline_noise_2.wav');
[y_off, fs_off] = audioread('/Users/amywong/Documents/MATLAB/nc4touch-data/data_march/baseline/baseline_fan_off.wav');

% Check raw signal properties BEFORE calibration
fprintf('=== RAW SIGNAL (no calibration) ===\n');
fprintf('Fan ON  — RMS: %.6f | Max: %.6f | Min: %.6f\n', rms(y_on),  max(y_on),  min(y_on));
fprintf('Fan OFF — RMS: %.6f | Max: %.6f | Min: %.6f\n', rms(y_off), max(y_off), min(y_off));

% Check calibration gain
data = load('/Users/amywong/Documents/MATLAB/nc4touch-data/audio_calibration/calibration_params.mat');
fprintf('\n=== CALIBRATION ===\n');
fprintf('Gain G: %.6f\n', data.calibrationGain_G);

% Check after calibration
yPa_on  = y_on  .* data.calibrationGain_G;
yPa_off = y_off .* data.calibrationGain_G;
fprintf('\n=== AFTER CALIBRATION ===\n');
fprintf('Fan ON  — RMS Pa: %.6f\n', rms(yPa_on));
fprintf('Fan OFF — RMS Pa: %.6f\n', rms(yPa_off));

% Final dB
dB_on  = paToDb(yPa_on);
dB_off = 10 * log10(mean(yPa_off.^2) / 20e-6);
fprintf('\n=== FINAL SPL ===\n');
fprintf('Fan ON:  %.2f dB\n', dB_on);
fprintf('Fan OFF: %.2f dB\n', dB_off);
fprintf('Difference: %.2f dB\n', dB_on - dB_off);

spikeTime = 4e7 / fs_off;  % convert samples to seconds
fprintf('Spike occurs at: %.2f seconds\n', spikeTime);

% Use only audio before the spike
y_off_clean = y_off(1:4e7);

% Recompute SPL on clean segment
yPa_off_clean = y_off_clean .* data.calibrationGain_G;
dB_off_clean = 10 * log10(mean(yPa_off_clean.^2) / (20e-6)^2);
fprintf('Fan OFF (clean): %.2f dB\n', dB_off_clean);
fprintf('Fan ON:          %.2f dB\n', dB_on);
fprintf('Difference:      %.2f dB\n', dB_on - dB_off_clean);