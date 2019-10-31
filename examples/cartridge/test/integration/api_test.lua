local t = require('luatest')
local g = t.group('integration_api')

local helper = require('test.helper.integration')
local cluster = helper.cluster

g.test_sample = function()
    t.assert_equals(
        cluster.main_server:http_request('POST', '/', {
            json = {text = 'User'},
            http = { headers = {['x-b3-sampled'] = 'true'}}
        }).json,
            {result = 'Hello, User'}
    )
end
