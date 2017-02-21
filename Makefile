SHELL = /bin/bash
LINK_FLAGS = --link-flags "-static"
PROG = redisniffer

.PHONY : all clean bin test spec
.PHONY : ${PROGS}

all: static

test: compile static version spec

static: src/bin/main.cr
	crystal build $^ -o ${PROG} ${LINK_FLAGS}

release: src/bin/main.cr
	crystal build --release $^ -o ${PROG} ${LINK_FLAGS}

spec:
	crystal spec -v

compile:
	@for x in src/bin/*.cr ; do\
	  crystal build "$$x" -o /dev/null ;\
	done

version: ${PROG}
	./$^ --version
