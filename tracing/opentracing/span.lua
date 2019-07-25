--- Span represents a unit of work executed on behalf of a trace.
-- Examples of spans include a remote procedure call, or a in-process method call
-- to a sub-component. Every span in a trace may have zero or more causal parents,
-- and these relationships transitively form a DAG. It is common for spans to
-- have at most one parent, and thus most traces are merely tree structures.
-- The internal data structure is modeled off the ZipKin Span JSON Structure
-- This makes it cheaper to convert to JSON for submission to the ZipKin HTTP api,
-- which Jaegar also implements.
--
-- You can find it documented in this OpenAPI spec:
--  https://github.com/openzipkin/zipkin-api/blob/7e33e977/zipkin2-api.yaml#L280
-- @module opentracing.span

local checks = require('checks')

local span_methods = {}
local span_mt = {
    __name = 'opentracing.span',
    __index = span_methods,
}

--- Create new span
-- @function new
-- @tparam table tracer
-- @tparam table context
-- @tparam string name
-- @tparam ?number start_timestamp
-- @treturn table span
local function new(tracer, context, name, start_timestamp)
    checks('table', 'table', 'string', '?number|cdata')
    return setmetatable({
        tracer = tracer,
        ctx = context,
        name = name,
        timestamp = start_timestamp or tracer:time(),
        duration = nil,
        -- Avoid allocations until needed
        baggage = {},
        tags = {},
        logs = {},
    }, span_mt)
end

--- Provides access to the `SpanContext` associated with this `Span`
-- The `SpanContext` contains state that propagates from `Span`
-- to `Span` in a larger tracer.
--
-- @function context
-- @tparam table self
-- @treturn table context
function span_methods:context()
    checks('table')
    return self.ctx
end

--- Provides access to the `Tracer` that created this span.
-- @function tracer
-- @tparam table self
-- @treturn table tracer the `Tracer` that created this span.
function span_methods:get_tracer()
    checks('table')
    return self.tracer
end

--- Changes the operation name
-- @function set_operation_name
-- @tparam table self
-- @tparam string name
-- @treturn table tracer
function span_methods:set_operation_name(name)
    checks('table', 'string')
    self.name = name
end

--- Start child span
-- @function start_child_span
-- @tparam table self
-- @tparam string name
-- @tparam ?number start_timestamp
-- @treturn table child span
function span_methods:start_child_span(name, start_timestamp)
    checks('table', 'string', '?number|cdata')
    return self.tracer:start_span(name, {
        start_timestamp = start_timestamp,
        child_of = self,
    })
end

--- Indicates the work represented by this `Span` has completed or
-- terminated.
--
-- If `finish` is called a second time, it is guaranteed to do nothing.
-- @function finish
-- @tparam table self
-- @tparam table opts
-- @tparam number ?opts.finish_timestamp a timestamp represented by microseconds
--  since the epoch to mark when the span ended. If unspecified, the current
--  time will be used.
-- @tparam string ?opts.error add error tag
-- @treturn[1] boolean `true`
-- @treturn[2] boolean `false`
-- @treturn[2] string error
function span_methods:finish(opts)
    opts = opts or {}
    checks('table', {
        timestamp = '?number|cdata',
        error = '?',
    })

    if self.duration ~= nil then
        return nil, 'span already finished'
    end

    if opts.timestamp == nil then
        self.duration = self.tracer:time() - self.timestamp
    else
        self.duration = opts.timestamp - self.timestamp
        if self.duration < 0 then
            return nil, 'Span duration can not be negative'
        end
    end

    if opts.error ~= nil then
        self:set_error(opts.error)
    end

    if self.ctx.should_sample then
        self.tracer:report(self)
    end
    return true
end

--- Attaches a key/value pair to the `Span`.
--
-- The value must be a string, bool, numeric type, or table of such values.
-- @function set_tag
-- @tparam table self
-- @tparam string key key or name of the tag. Must be a string.
-- @tparam any value value of the tag
-- @treturn boolean `true`
function span_methods:set_tag(key, value)
    checks('table', 'string', '?')
    self.tags[key] = value
    return true
end

--- Get span's tag
-- @function get_tag
-- @tparam table self
-- @tparam string key
-- @treturn any tag value
function span_methods:get_tag(key)
    checks('table', 'string')
    local tags = self.tags
    if tags then
        return tags[key]
    else
        return nil
    end
end

--- Get tags iterator
-- @function each_tag
-- @tparam table self
-- @treturn function iterator
-- @treturn table tags
function span_methods:each_tag()
    checks('table')
    local tags = self.tags
    if tags == nil then
        return function() end
    end
    return next, tags
end

--- Get copy of span's tags
-- @function tags
-- @tparam table self
-- @treturn table tags
function span_methods:tags()
    checks('table')
    return table.deepcopy(self.tags)
end

--- Log some action
-- @function log
-- @tparam table self
-- @tparam table key
-- @tparam table value
-- @tparam ?number timestamp
-- @treturn boolean `true`
function span_methods:log(key, value, timestamp)
    -- `value` is allowed to be anything.
    checks('table', 'string', '?', '?number|cdata')
    timestamp = timestamp or self.tracer:time()
    table.insert(self.logs, {
        key = key,
        value = value,
        timestamp = timestamp,
    })
    return true
end

--- Attaches a log record to the `Span`.
--
-- @usage
--    span:log_kv({
--      ["event"] = "time to first byte",
--      ["packet.size"] = packet:size()})
--
-- @function log_kv
-- @tparam table self
-- @tparam table key_values a table of string keys and values of string, bool, or
--   numeric types
-- @tparam ?number timestamp an optional timestamp as a unix timestamp.
--   defaults to the current time
-- @treturn boolean `true`
function span_methods:log_kv(key_values, timestamp)
    checks('table', 'table', '?number|cdata')
    timestamp = timestamp or self.tracer:time()

    for key, value in pairs(key_values) do
        table.insert(self.logs, {
            key = key,
            value = value,
            timestamp = timestamp,
        })
    end

    return true
end

--- Get span's logs iterator
-- @function each_log
-- @tparam table self
-- @treturn function log iterator
-- @treturn table logs
function span_methods:each_log()
    checks('table')
    local i = 0
    return function(logs)
        if i >= #self.logs then
            return
        end
        i = i + 1
        local log = logs[i]
        return log.key, log.value, log.timestamp
    end, self.logs
end

--- Stores a Baggage item in the `Span` as a key/value pair.
--
-- Enables powerful distributed context propagation functionality where
-- arbitrary application data can be carried along the full path of request
-- execution throughout the system.
--
-- Note 1: Baggage is only propagated to the future (recursive) children of this
-- `Span`.
--
-- Note 2: Baggage is sent in-band with every subsequent local and remote calls,
-- so this feature must be used with care.
-- @function set_baggage_item
-- @tparam table self
-- @tparam string key Baggage item key
-- @tparam string value Baggage item value
-- @treturn boolean `true`
function span_methods:set_baggage_item(key, value)
    checks('table', 'string', 'string')
    -- Create new context so that baggage is immutably passed around
    self.ctx = self.ctx:clone_with_baggage_item(key, value)
    return true
end

--- Retrieves value of the baggage item with the given key.
-- @function get_baggage_item
-- @tparam table self
-- @tparam string key
-- @treturn string value
function span_methods:get_baggage_item(key)
    checks('table', 'string')
    return self.ctx:get_baggage_item(key)
end

--- Returns an iterator over each attached baggage item
-- @function each_baggage_item
-- @tparam table self
-- @treturn function iterator
-- @treturn table baggage
function span_methods:each_baggage_item()
    checks('table')
    return self.ctx:each_baggage_item()
end

--- Extension. Inspired by https://github.com/opentracing/opentracing-go/blob/master/ext/tags.go
-- See all possible tags:
--  https://github.com/opentracing/specification/blob/master/semantic_conventions.md#standard-span-tags-and-log-fields

local span_tag = {
    component = 'component',
    db_instance = 'db.instance',
    db_statement = 'db.statement',
    db_type = 'db.type',
    db_user = 'db.user',
    http_method = 'http.method',
    http_status_code = 'http.status_code',
    http_url = 'http.url',
    message_bus_destination = 'message_bus.destination',
    peer_address = 'peer.address',
    peer_hostname = 'peer.hostname',
    peer_ipv4 = 'peer.ipv4',
    peer_ipv6 = 'peer.ipv6',
    peer_port = 'peer.port',
    peer_service = 'peer.service',
    sampling_priority = 'sampling.priority',
    span_kind = 'span.kind',
-- ZipKin specific tags
-- See https://zipkin.io/public/thrift/v1/zipkinCore.html
    error = 'error',
    client_send = 'cs',
    client_received = 'cr',
    server_send = 'ss',
    server_received = 'sr',
    message_send = 'ms',
    message_received = 'mr',
    http_host = 'http.host',
    http_path = 'http.path',
    http_route = 'http.route',
    http_request_size = 'http.request.size',
    http_response_size = 'http.response.size',
    local_component = 'lc',
    client_addr = 'ca',
    server_addr = 'sa',
    message_addr = 'ma',
}

--- Set component tag (The software package, framework, library, or module that generated the associated Span.)
-- @function set_component
-- @tparam table self
-- @tparam string component
function span_methods:set_component(component)
    self:set_tag(span_tag.component, component)
end

--- Set HTTP method of the request for the associated Span
-- @function set_http_method
-- @tparam table self
-- @tparam string method
function span_methods:set_http_method(method)
    self:set_tag(span_tag.http_method, method)
end

--- Set HTTP response status code for the associated Span
-- @function set_http_status_code
-- @tparam table self
-- @tparam number status_code
function span_methods:set_http_status_code(status_code)
    self:set_tag(span_tag.http_status_code, status_code)
end

--- Set URL of the request being handled in this segment of the trace, in standard URI format
-- @function set_http_url
-- @tparam table self
-- @tparam string url
function span_methods:set_http_url(url)
    self:set_tag(span_tag.http_url, url)
end

--- Set the domain portion of the URL or host header.
--   Used to filter by host as opposed to ip address.
-- @function set_http_host
-- @tparam table self
-- @tparam string host
function span_methods:set_http_host(host)
    self:set_tag(span_tag.http_host, host)
end

--- Set the absolute http path, without any query parameters.
--   Used as a filter or to clarify the request path for a given route. For example, the path for
--   a route "/objects/:objectId" could be "/objects/abdc-ff". This does not limit cardinality like
--   HTTP_ROUTE("http.route") can, so is not a good input to a span name.
--
--   The Zipkin query api only supports equals filters. Dropping query parameters makes the number
--   of distinct URIs less. For example, one can query for the same resource, regardless of signing
--   parameters encoded in the query line. Dropping query parameters also limits the security impact
--   of this tag.
-- @function set_http_path
-- @tparam table self
-- @tparam string path
function span_methods:set_http_path(path)
    self:set_tag(span_tag.http_path, path)
end

--- Set the route which a request matched or "" (empty string) if routing is supported, but there was no match.
--   Unlike HTTP_PATH("http.path"), this value is fixed cardinality, so is a safe input to a span
--   name function or a metrics dimension. Different formats are possible. For example, the following
--   are all valid route templates: "/users" "/users/:userId" "/users/*"
--
--   Route-based span name generation often uses other tags, such as HTTP_METHOD("http.method") and
--   HTTP_STATUS_CODE("http.status_code"). Route-based names can look like "get /users/{userId}",
--   "post /users", "get not_found" or "get redirected".
-- @function set_http_route
-- @tparam table self
-- @tparam string route
function span_methods:set_http_route(route)
    self:set_tag(span_tag.http_route, route)
end

--- Set the size of the non-empty HTTP request body, in bytes.
--   Large uploads can exceed limits or contribute directly to latency.
-- @function set_http_request_size
-- @tparam table self
-- @tparam string host
function span_methods:set_http_request_size(size)
    self:set_tag(span_tag.http_request_size, size)
end

--- Set the size of the non-empty HTTP response body, in bytes.
--   Large downloads can exceed limits or contribute directly to latency.
-- @function set_response_size
-- @tparam table self
-- @tparam string host
function span_methods:set_response_size(size)
    self:set_tag(span_tag.http_response_size, size)
end

--- Set remote "address", suitable for use in a networking client library.
--   This may be a "ip:port", a bare "hostname", a FQDN, or even a JDBC substring like "mysql://prod-db:3306"
-- @function set_peer_address
-- @tparam table self
-- @tparam string address
function span_methods:set_peer_address(address)
    self:set_tag(span_tag.peer_address, address)
end

--- Set remote hostname
-- @function set_peer_hostname
-- @tparam table self
-- @tparam string hostname
function span_methods:set_peer_hostname(hostname)
    self:set_tag(span_tag.peer_hostname, hostname)
end

--- Set remote IPv4 address as a .-separated tuple
-- @function set_peer_ipv4
-- @tparam table self
-- @tparam string IPv4
function span_methods:set_peer_ipv4(ipv4)
    self:set_tag(span_tag.peer_ipv4, ipv4)
end

--- Set remote IPv6 address as a string of colon-separated 4-char hex tuples
-- @function set_peer_ipv6
-- @tparam table self
-- @tparam string IPv6
function span_methods:set_peer_ipv6(ipv6)
    self:set_tag(span_tag.peer_ipv6, ipv6)
end

--- Set remote port
-- @function set_peer_port
-- @tparam table self
-- @tparam number port
function span_methods:set_peer_port(port)
    self:set_tag(span_tag.peer_port, tonumber(port))
end

--- Set remote service name (for some unspecified definition of "service")
-- @function set_peer_service
-- @tparam table self
-- @tparam string service_name
function span_methods:set_peer_service(service)
    self:set_tag(span_tag.peer_service, service)
end

--- Set sampling priority
--   If greater than 0, a hint to the Tracer to do its best to capture the trace.
--   If 0, a hint to the trace to not-capture the trace.
--   If absent, the Tracer should use its default sampling mechanism.
-- @function set_sampling_priority
-- @tparam table self
-- @tparam number priority
function span_methods:set_sampling_priority(priority)
    self:set_tag(span_tag.sampling_priority, priority)
end

local span_kind = {
    client = 'client',
    server = 'server',
    producer = 'producer',
    consumer = 'consumer',
}

--- Set span's king
-- Either "client" or "server" for the appropriate roles in an RPC,
--  and "producer" or "consumer" for the appropriate roles in a messaging scenario.
-- @function set_kind
-- @tparam table self
-- @tparam string kind
function span_methods:set_kind(kind)
    self:set_tag(span_tag.span_kind, kind)
end

--- Set client kind to span
-- @function set_client_kind
-- @tparam table self
function span_methods:set_client_kind()
    self:set_tag(span_tag.span_kind, span_kind.client)
end

--- Set server kind to span
-- @function set_server_kind
-- @tparam table self
function span_methods:set_server_kind()
    self:set_tag(span_tag.span_kind, span_kind.server)
end

--- Set producer kind to span
-- @function set_producer_kind
-- @tparam table self
function span_methods:set_producer_kind()
    self:set_tag(span_tag.span_kind, span_kind.producer)
end

--- Set consumer kind to span
-- @function set_consumer_kind
-- @tparam table self
function span_methods:set_consumer_kind()
    self:set_tag(span_tag.span_kind, span_kind.consumer)
end

-- OpenTracing semantic conventions says that error tag should be a string
-- However ZipKin reports error as message:
-- https://cloud.spring.io/spring-cloud-sleuth/2.0.x/single/spring-cloud-sleuth.html#_visualizing_errors
--- Set error
-- @function set_component
-- @tparam table self
-- @tparam string err
function span_methods:set_error(err)
    self:set_tag(span_tag.error, err)
end

return {
    new = new,
}
