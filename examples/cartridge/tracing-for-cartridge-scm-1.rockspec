package = 'tracing-for-cartridge'
version = 'scm-1'
source  = {
    url = '/dev/null',
}

dependencies = {
    'tarantool',
    'cartridge == 2.3.0-1',
    'tracing',
}
build = {
    type = 'none';
}
