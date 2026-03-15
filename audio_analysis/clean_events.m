function clean_evts = clean_events(eventFile)
    raw      = fileread(eventFile);
    rawClean = regexprep(raw,      '^\s*#.*\n',                '', 'lineanchors');
    rawClean = regexprep(rawClean, '^\s*\{"header":.*?\}\s*',  '');
    rawClean = regexprep(rawClean, '^\s*\}\s*',                '');
    rawClean = regexprep(rawClean, '}\s*{',                    '},{');
    rawClean = ['[' rawClean ']'];
    clean_evts = jsondecode(rawClean);
end
