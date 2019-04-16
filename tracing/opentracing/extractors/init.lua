local http = require('opentracing.extractors.http')
local map = require('opentracing.extractors.map')

local extractor = {
    http = http,
    map = map,
}

return extractor
