std = {
    read_globals = {'require', 'debug', 'pcall', 'xpcall', 'tostring',
        'tonumber', 'type', 'assert', 'ipairs', 'math', 'error', 'string',
        'table', 'pairs', 'os', 'io', 'select', 'unpack', 'dofile', 'next',
        'loadstring', 'setfenv', 'utf8',
        'rawget', 'rawset',
        'getmetatable', 'setmetatable',
    },
    globals = {'package', 'box'}
}
redefined = False
