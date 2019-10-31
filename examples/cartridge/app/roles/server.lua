local json = require('json')

local cartridge = require('cartridge')
local membership = require('membership')
local opentracing = require('opentracing')

local role_name = 'server'

local service_uri = ('%s@%s'):format(role_name, membership.myself().uri)

local function init(_)
    local httpd = cartridge.service_get('httpd')
    httpd:route({method = 'POST', path = '/'}, function(req)
        local ok, body = pcall(req.json, req)
        if not ok then
            return {
                body = json.encode({
                    status = 'Invalid body',
                    error = body,
                }),
                status = 400,
            }
        elseif body['text'] == nil then
            return {
                body = json.encode({
                    status = 'Invalid body',
                    error = 'No text field',
                }),
                status = 400,
            }
        end

        local context = opentracing.http_extract(req.headers)
        local span = opentracing.start_span_from_context(context, 'HTTP request processing')
        span:set_component(service_uri)
        span:set_server_kind()
        span:set_http_method(req.method)
        span:set_http_path(req.path)

        local rpc_context = {}
        opentracing.map_inject(span:context(), rpc_context)

        local text, err = cartridge.rpc_call('formatter', 'format',
                {rpc_context, body.text})

        if err ~= nil then
            span:finish()
            return {
                body = json.encode({
                    status = 'RPC error',
                    error = err,
                }),
                status = 500,
            }
        end


        local result, err = cartridge.rpc_call('printer', 'print',
                {rpc_context, text})

        if err ~= nil then
            span:finish()
            return {
                body = json.encode({
                    status = 'RPC error',
                    error = err,
                }),
                status = 500,
            }
        end

        span:finish()

        return {
            body = json.encode({result = result})
        }
    end)

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
    role_name = role_name,
    init = init,
    stop = stop,
    validate_config = validate_config,
    apply_config = apply_config,
    dependencies = {'app.roles.tracing'},
}
