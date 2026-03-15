% config.m
% =========================================================================
% NC4Touch Audio Analysis — Central Configuration
%
% INSTRUCTIONS:
%   1. Update Section A (paths) once when setting up on a new machine
%   2. Update Section B (conditions) each time you have a new recording session
%   3. Everything else is automatic — do not edit below Section B
% =========================================================================

%% -------------------------------------------------------------------------
%% SECTION A — Machine paths (edit once per machine)
%% -------------------------------------------------------------------------
projectRoot = '/Users/amywong/Documents/MATLAB/nc4touch-data';

%% -------------------------------------------------------------------------
%% SECTION B — Session data (edit each recording session)
%% -------------------------------------------------------------------------

% --- Condition 1: Box Closed ---
cfg.conditions(1).name       = 'box_closed';
cfg.conditions(1).audioFile  = 'phase_2_2.wav';        % filename only
cfg.conditions(1).audioStart = datetime('2026-03-09 14:43:21.100', ...
                                   'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');  % from Audacity
cfg.conditions(1).eventFile  = 'phase_2_2.json';       % filename only

% --- Condition 2: Box Open ---
cfg.conditions(2).name       = 'box_open';
cfg.conditions(2).audioFile  = 'phase_2b_2.wav';       % filename only
cfg.conditions(2).audioStart = datetime('2026-03-09 14:34:58.100', ...
                                   'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');  % from Audacity
cfg.conditions(2).eventFile  = 'phase_2b_2.json';      % filename only

%% -------------------------------------------------------------------------
%% AUTOMATIC — do not edit below this line
%% -------------------------------------------------------------------------

% --- Directories ---
cfg.projectRoot  = projectRoot;
cfg.dataDir      = fullfile(projectRoot, 'data_march');
cfg.calibDir     = fullfile(projectRoot, 'audio_calibration');
cfg.analysisDir  = fullfile(projectRoot, 'analysis');
cfg.baselineFile  = fullfile(projectRoot, 'data_march', 'baseline', 'baseline_noise_2.wav');

% --- Calibration ---
cfg.calibPath      = fullfile(cfg.calibDir, 'calibration_params.mat');
cfg.calibUIOutput  = fullfile(cfg.calibDir, 'calibration_ui_output.mat');
cfg.calibAudioFile = fullfile(cfg.calibDir, 'sound_calibration_013026.wav');

% --- Analysis settings ---
cfg.audioBandFilter = [200, 90000];  % Hz
cfg.baselineMean    = 34.70;         % dB SPL — from baseline recording

% --- Resolve full paths for each condition ---
for c = 1:numel(cfg.conditions)
    cfg.conditions(c).audioFile    = fullfile(cfg.dataDir,    cfg.conditions(c).audioFile);
    cfg.conditions(c).eventFile    = fullfile(cfg.dataDir,    cfg.conditions(c).eventFile);
    cfg.conditions(c).trimmedFile  = fullfile(cfg.analysisDir, ...
        sprintf('trimmed_%s.wav',    cfg.conditions(c).name));
    cfg.conditions(c).extractedDir = fullfile(cfg.analysisDir, ...
        sprintf('extracted_%s',      cfg.conditions(c).name));
    cfg.conditions(c).statsFile    = fullfile(cfg.analysisDir, ...
        sprintf('%s_eventStats.mat', cfg.conditions(c).name));
end

fprintf('[CONFIG] Loaded. Project root: %s\n', projectRoot);