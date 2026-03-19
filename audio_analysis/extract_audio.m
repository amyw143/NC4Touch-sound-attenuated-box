
function extract_audio(trialArray, trialNum, audioFile, audioStart, outputFolder)
    if ~isfolder(outputFolder), mkdir(outputFolder); end

    [y, fs] = audioread(audioFile);
    audio_ts = seconds((0:length(y)-1) / fs) + audioStart;

    for k = 1:size(trialArray,1)
        eventName = strtrim(string(trialArray(k,1)));
        rawStart  = strtrim(string(trialArray(k,2)));
        rawEnd    = strtrim(string(trialArray(k,3)));

        try
            tStartDT = parse_timestamp(rawStart);
            tEndDT   = parse_timestamp(rawEnd);
        catch
            warning('Failed to parse timestamps for %s (trial %d)', eventName, trialNum);
            continue
        end

        idx = audio_ts >= tStartDT & audio_ts < tEndDT;
        if ~any(idx)
            warning('Event %s out of range or zero length', eventName);
            continue
        end
        ySeg = y(idx, :);
        
        outName = sprintf('%s_trial%d.wav', regexprep(eventName,'[^\w-]','_'), trialNum);
        audiowrite(fullfile(outputFolder, outName), ySeg, fs);
    end
    fprintf('[INFO] Trial %d: audio segments saved.\n', trialNum);
end
