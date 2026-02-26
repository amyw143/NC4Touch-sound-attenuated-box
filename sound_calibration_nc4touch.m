clear log_utils

% Setup folders
dataset_root = '/Users/amywong/data/nc4touch';
out_dir_name = 'audio_calibration';
dataDir = fullfile(dataset_root, out_dir_name);
if ~exist(dataDir, 'dir')
    mkdir(dataDir);
end

logDir = fullfile(dataDir, 'results');
if ~exist(logDir, 'dir')
    mkdir(logDir);
end

logFile = fullfile(logDir, 'calibration.log');

% Start logging
fid = log_utils.start(logFile);  % <-- store output to check
disp(fid)                        % Should be a positive integer

% Test writing
log_utils.printf('Test message\n');


calibration_ui(logFile)
