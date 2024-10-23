#! /bin/bash
SHELL:=/bin/bash

.PHONY: all doc
all:
	mkdir -p doc

doc:
	ldoc -t "tracing-${version}" -p "tracing (${version})" --all .

.PHONY: build
build:
	tarantoolctl rocks make

.PHONY: lint
lint:
	luacheck ./tracing --config=.luacheckrc --no-redefined --no-unused-args
	luacheck ./test --config=.luacheckrc --no-redefined --no-unused-args

TEST_FILES := \
	$(shell find $(CURDIR)/test -type f -path */resources/* -prune -o -name *.lua -print)

.PHONY: unit
unit:
	TEST_RESULT=0; \
	for f in $(TEST_FILES); do \
		echo -e '\nExecuting test '$(basename $$f)'...'; \
		tarantool -e "require('luacov.runner')(); dofile('$$f')" || TEST_RESULT=$$?; \
		[ $$TEST_RESULT -gt 0 ] && exit $$TEST_RESULT; \
	done; \
	luacov; \
	luacov-console; \
	exit $$TEST_RESULT
