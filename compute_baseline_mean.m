calibPath = "/Users/amywong/Documents/MATLAB/nc4touch-data/audio_calibration/calibration_params.mat";

% Load calibration 
data = load(calibPath);
calibrationGain_G = data.calibrationGain_G;
fprintf('[INFO] Calibration gain loaded: %.6f\n', calibrationGain_G);

%% ------------- PROCESS ALL BASELINE FILES -------------

phase1Dir = "/Users/amywong/Documents/MATLAB/nc4touch-data/phase_1";

audioFiles = dir(fullfile(phase1Dir, '*.wav'));

baseline_dB_all = zeros(length(audioFiles), 1);

for f = 1:length(audioFiles)

    filePath = fullfile(phase1Dir, audioFiles(f).name);

    [y, fs] = audioread(filePath);

    % Apply calibration
    yPa = apply_audio_calibration(y, calibrationGain_G);

    % Compute dB envelope
    yDB = compute_audio_dB_envelope(yPa, fs);

    % Store mean SPL for this file
    baseline_dB_all(f) = mean(yDB);

    fprintf('[INFO] %s: %.2f dB\n', ...
        audioFiles(f).name, baseline_dB_all(f));

end

% Compute overall baseline mean
baselineMean = mean(baseline_dB_all);

fprintf('\n[INFO] Overall Baseline Mean SPL: %.2f dB\n', baselineMean);


% -------------------------------------------------------------------------

function audioPa = apply_audio_calibration(audioData, calibrationGain_G)
    ref_Pa = 20e-6;
    audioPa = audioData .* calibrationGain_G .* ref_Pa;
end

function audioDB = compute_audio_dB_envelope(audioPa, audioFs)
    rmsWindow_ms = 20;
    ref_Pa = 20e-6;

    winSamples = round(audioFs * rmsWindow_ms / 1000);
    rmsEnvelope = sqrt(movmean(audioPa.^2, winSamples));

    audioDB = 20 * log10(rmsEnvelope / ref_Pa);
end