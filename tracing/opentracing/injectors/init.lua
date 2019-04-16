local http = require('opentracing.injectors.http')
local map = require('opentracing.injectors.map')

local injector = {
    http = http,
    map = map,
}

return injector
