local fiber = require('fiber')
local opentracing = require('opentracing')
local membership = require('membership')

local role_name = 'printer'

local service_uri = ('%s@%s'):format(role_name, membership.myself().uri)

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

local function print_function(ctx, input)
    fiber.sleep(0.5)

    local context = opentracing.map_extract(ctx)
    local span = opentracing.start_span_from_context(context, 'print')
    span:set_component(service_uri)

    print(input)
    fiber.sleep(0.5)

    span:finish()

    fiber.sleep(0.5)
    return input
end

return {
    print = print_function,

    role_name = role_name,
    init = init,
    stop = stop,
    validate_config = validate_config,
    apply_config = apply_config,
    dependencies = {},
}
