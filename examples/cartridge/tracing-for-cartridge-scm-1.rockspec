package = 'tracing-for-cartridge'
version = 'scm-1'
source  = {
    url = '/dev/null',
}

dependencies = {
    'tarantool',
    'luatest == 0.3.0-1',
    'cartridge == 1.2.0-1',
    'tracing',
}
build = {
    type = 'none';
}
