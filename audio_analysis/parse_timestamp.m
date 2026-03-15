function T = parse_timestamp(raw)
    raw   = string(raw);
    parts = split(raw, "_");
    if numel(parts) < 3
        error('Unexpected timestamp format: %s', raw);
    end
    datePart = parts(1); timePart = parts(2); fracPart = parts(3);

    yyyy = extractBetween(datePart,1,4);
    mm   = extractBetween(datePart,5,6);
    dd   = extractBetween(datePart,7,8);
    HH   = extractBetween(timePart,1,2);
    MM   = extractBetween(timePart,3,4);
    SS   = extractBetween(timePart,5,6);

    ms = fracPart;
    if strlength(ms) >= 3, ms = extractBetween(ms,1,3);
    else, ms = ms + repmat("0", 1, 3 - strlength(ms));
    end

    T = datetime(yyyy+"-"+mm+"-"+dd+" "+HH+":"+MM+":"+SS+"."+ms, ...
        'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
end