# I'm sure there is better way. But I would need to find it first
MK_FILE_PATH = $(lastword $(MAKEFILE_LIST))
PRJ_DIR      = $(abspath $(dir $(MK_FILE_PATH)))
GOPATH_BUILD = $(PRJ_DIR)/build
COVER_DIR    = $(GOPATH_BUILD)/coverage
TOOLS_DIR   ?= $(GOPATH)/bin
ETC_DIR      = $(PRJ_DIR)/.etc
OPTS         ?=
NOASM        ?=
GO           ?= go
GOLANGCILINT ?= golangci-lint
# -run="^_" as we want to avoid running tests by 'bench' and there never be a test starting with _
BENCH_OPTS   ?= -bench=. -run="^_" -benchmem
V            ?= 1
GOARCH       ?=
BUILD_ARCH   = $(shell $(GO) env GOARCH)

ifeq ($(NOASM),1)
	OPTS+=--tags purego
endif

ifeq ($(V),1)
	OPTS += -v              # Be verbose
endif

all: build

lint:
	$(GOLANGCILINT) run

lint-fix:
	$(GOLANGCILINT) run --fix

build:
	$(GO) build ./...

generate: clean
	$(GO) generate -v ./...

clean:
	rm -rf $(GOPATH_BUILD)
