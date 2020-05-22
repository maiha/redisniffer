PROG = redisniffer

all: static

ci: spec release version

static:
	shards build $(PROG) --link-flags "-static"

release:
	shards build $(PROG) --link-flags "-static" --release

.PHONY: spec
spec:
	crystal spec -v

version: ./bin/${PROG}
	$^ --version
