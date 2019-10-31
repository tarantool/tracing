local opentracing = require('opentracing')
local zipkin = require('zipkin.tracer')

local log = require('log')

--[[

By default tracing is disabled, you can enable it
using special header in HTTP request
("x-b3-sampled: 1" or "x-b3-sampled: true")

```bash
curl --request POST \
  --url http://127.0.0.1:8081/ \
  --header 'x-b3-sampled: 1' \
  --data '{"text": "<Username>"}'
```
--]]

local function init()
    return true
end

local function stop()
    return true
end

local function validate_config(_, _)
    -- validate your tracing config here
    return true
end

local default_cfg = {
    base_url = 'localhost:9411/api/v2/spans',
    api_method = 'POST',
    report_interval = 5,    -- in seconds
    spans_limit = 1e4,      -- amount of spans that could be stored locally
}

local function apply_config(cfg, _)
    cfg = cfg and cfg['tracing'] or {}
    -- sample all requests
    local sampler = { sample = function() return true end }

    local tracer = zipkin.new({
        base_url = cfg.base_url or default_cfg.base_url,
        api_method = cfg.api_method or default_cfg.api_method,
        report_interval = cfg.report_interval or default_cfg.report_interval,
        spans_limit = cfg.spans_limit or default_cfg.spans_limit,
        on_error = function(err) log.error('Tracing error: %s', err) end,
    }, sampler)
    opentracing.set_global_tracer(tracer)

    return true
end

return {
    role_name = 'tracing',
    init = init,
    stop = stop,
    validate_config = validate_config,
    apply_config = apply_config,
    dependencies = {},
}
