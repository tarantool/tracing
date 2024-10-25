#! /bin/bash
SHELL:=/bin/bash

.PHONY: all doc
all:
	mkdir -p doc

doc:
	ldoc -t "tracing-${version}" -p "tracing (${version})" --all .

.PHONY: build
build:
	tt rocks make

.PHONY: lint
lint:
	luacheck ./tracing --config=.luacheckrc --no-redefined --no-unused-args
	luacheck ./test --config=.luacheckrc --no-redefined --no-unused-args

TEST_FILES := \
	$(shell find $(CURDIR)/test -type f -path */resources/* -prune -o -name *.lua -print)

.PHONY: unit
unit:
	rm -f luacov.*.out* && .rocks/bin/luatest -v --coverage && .rocks/bin/luacov . && grep -A999 '^Summary' luacov.report.out
