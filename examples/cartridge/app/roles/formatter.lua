local fiber = require('fiber')
local opentracing = require('opentracing')
local membership = require('membership')

local role_name = 'formatter'
local template = 'Hello, %s'

local service_uri = ('%s@%s'):format(role_name, membership.myself().uri)

local function format(ctx, input)
    fiber.sleep(0.5)

    local context = opentracing.map_extract(ctx)
    local span = opentracing.start_span_from_context(context, 'format')
    span:set_component(service_uri)

    fiber.sleep(0.5)

    local result, err
    if input == '' then
        err = 'Empty string'
        span:set_error(err)
    else
        result = template:format(input)
    end

    span:finish()

    fiber.sleep(0.5)

    return result, err
end

local function init(_)
    return true
end

local function stop()
end

local function validate_config(_, _)
    return true
end

local function apply_config(_, _)
    return true
end

return {
    format = format,

    role_name = role_name,
    init = init,
    stop = stop,
    validate_config = validate_config,
    apply_config = apply_config,
    dependencies = {},
}
