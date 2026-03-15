
function extract_audio(trialArray, trialNum, audioFile, fileStartTime, outputFolder)
    if ~isfolder(outputFolder), mkdir(outputFolder); end

    info         = audioinfo(audioFile);
    fs           = info.SampleRate;
    durationFile = info.Duration;

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

        t0 = max(0,            seconds(tStartDT - fileStartTime));
        t1 = min(durationFile, seconds(tEndDT   - fileStartTime));

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
