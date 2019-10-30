local checks = require('checks')

local function inject(context, carrier)
    checks('table', '?table')
    carrier = carrier or table.new(0, 5)
    carrier.trace_id = context.trace_id
    carrier.parent_id = context.parent_id
    carrier.span_id = context.span_id
    carrier.sample = context.should_sample
    if context.baggage ~= nil then
        local baggage = table.deepcopy(context.baggage)
        carrier.baggage = setmetatable(baggage, nil)
    end
    return carrier
end

return inject
