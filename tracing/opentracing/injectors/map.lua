local checks = require('checks')

local function inject(context, carrier)
    checks('table', '?table')
    carrier = carrier or table.new(0, 5)
    carrier.trace_id = context.trace_id
    carrier.parent_id = context.parent_id
    carrier.span_id = context.span_id
    carrier.sample = context.should_sample
    local baggage = table.deepcopy(context.baggage)
    carrier.baggage = setmetatable(baggage, nil)
    return carrier
end

return inject
