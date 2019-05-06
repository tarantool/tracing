local function validate_span_id(span_id)
    if span_id == nil then
        return true
    end
    return (#span_id == 8 or #span_id == 16) and span_id:match("%X") == nil
end

local function validate(carrier)
    -- Validate trace id
    local trace_id = carrier.trace_id
    if trace_id ~= nil and ((#trace_id ~= 16 and #trace_id ~= 32) or trace_id:match("%X")) then
        return false, 'Invalid trace id'
    end

    -- Validate parent_span_id
    if not validate_span_id(carrier.parent_span_id) then
        return false, 'Invalid parent span id'
    end

    -- Validate request_span_id
    if not validate_span_id(carrier.span_id) then
        return false, 'Invalid span id'
    end
    return true
end

return validate
