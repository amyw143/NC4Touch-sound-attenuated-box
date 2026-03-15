function event_windows = extract_event_windows(events)
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
