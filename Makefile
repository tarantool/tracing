.PHONY: build
build:
	cd third_party/background && tarantoolctl rocks make && rsync --recursive .rocks/ ../../.rocks
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
		echo '\nExecuting test '$(basename $$f)'...'; \
		$$f; \
		let TEST_RESULT=$$TEST_RESULT+$$?; \
		[ $$TEST_RESULT -gt 0 ] && exit $$TEST_RESULT; \
	done; \
	exit $$TEST_RESULT
