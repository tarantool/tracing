#!/bin/sh
# Call this scripts to install dependencies

set -e

tarantoolctl rocks make
tarantoolctl rocks install luacheck 0.25.0
tarantoolctl rocks install luatest 0.5.0
