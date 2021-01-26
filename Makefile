################################################################################
# Environment Variables
################################################################################

DOCKER_IMAGE_REPOS  := takumi/hraftd-playground
GOLANG_IMAGE_DOMAIN := docker.io/library/golang
GOLANG_IMAGE_BRANCH := alpine
ALPINE_IMAGE_DOMAIN := docker.io/library/alpine
ALPINE_IMAGE_BRANCH := latest

################################################################################
# Version
################################################################################

NAME    := hraftd
VERSION := 0.0.1

ifeq (,$(wildcard ../.git/HEAD))
REVISION := ${GIT_SHA1_HASH}
else
REVISION := $(shell git rev-parse --short HEAD)
endif

################################################################################
# Go Build
################################################################################

SRCS := $(shell find $(CURDIR) -type f -name '*.go')

GOOS   := linux
GOARCH := amd64

LDFLAGS_NAME     := -X "main.name=$(NAME)"
LDFLAGS_VERSION  := -X "main.version=v$(VERSION)"
LDFLAGS_REVISION := -X "main.revision=$(REVISION)"
LDFLAGS          := -ldflags '$(LDFLAGS_NAME) $(LDFLAGS_VERSION) $(LDFLAGS_REVISION)'

################################################################################
# Docker Build
################################################################################

GOLANG_IMAGE := $(GOLANG_IMAGE_DOMAIN):$(GOLANG_IMAGE_BRANCH)
ALPINE_IMAGE := $(ALPINE_IMAGE_DOMAIN):$(ALPINE_IMAGE_BRANCH)

BUILD_ARGS ?= --build-arg GOLANG_IMAGE_DOMAIN=$(GOLANG_IMAGE_DOMAIN) \
              --build-arg GOLANG_IMAGE_BRANCH=$(GOLANG_IMAGE_BRANCH) \
              --build-arg ALPINE_IMAGE_DOMAIN=$(ALPINE_IMAGE_DOMAIN) \
              --build-arg ALPINE_IMAGE_BRANCH=$(ALPINE_IMAGE_BRANCH)

ifneq (x${no_proxy}x,xx)
BUILD_ARGS += --build-arg no_proxy=${no_proxy}
endif
ifneq (x${NO_PROXY}x,xx)
BUILD_ARGS += --build-arg NO_PROXY=${NO_PROXY}
endif

ifneq (x${ftp_proxy}x,xx)
BUILD_ARGS += --build-arg ftp_proxy=${ftp_proxy}
endif
ifneq (x${FTP_PROXY}x,xx)
BUILD_ARGS += --build-arg FTP_PROXY=${FTP_PROXY}
endif

ifneq (x${http_proxy}x,xx)
BUILD_ARGS += --build-arg http_proxy=${http_proxy}
endif
ifneq (x${HTTP_PROXY}x,xx)
BUILD_ARGS += --build-arg HTTP_PROXY=${HTTP_PROXY}
endif

ifneq (x${https_proxy}x,xx)
BUILD_ARGS += --build-arg https_proxy=${https_proxy}
endif
ifneq (x${HTTPS_PROXY}x,xx)
BUILD_ARGS += --build-arg HTTPS_PROXY=${HTTPS_PROXY}
endif

RUN_ARGS ?= REPOSITORY=$(DOCKER_IMAGE_REPOS)

################################################################################
# Default Target
################################################################################

.PHONY: all
all: $(NAME) docker

################################################################################
# Binary Target
################################################################################

.PHONY: $(NAME)
$(NAME): $(CURDIR)/bin/$(NAME)
$(CURDIR)/bin/$(NAME): $(SRCS)
	@cd $(CURDIR)/hraftd && GOOS=$(GOOS) GOARCH=$(GOARCH) go build $(LDFLAGS) -o $@

################################################################################
# Archive Target
################################################################################

$(CURDIR)/bin/$(NAME).zip: $(CURDIR)/bin/$(NAME)
	@cd $(CURDIR)/bin && zip $@ $(NAME)

################################################################################
# Running Target
################################################################################

.PHONY: run
run: $(CURDIR)/bin/$(NAME)
	@$(CURDIR)/bin/$(NAME)

################################################################################
# Docker Target
################################################################################

.PHONY: docker
docker:
	@docker build --cache-from $(GOLANG_IMAGE) --target builder -t $(DOCKER_IMAGE_REPOS):builder $(BUILD_ARGS) .
	@docker build --cache-from $(ALPINE_IMAGE) --target service -t $(DOCKER_IMAGE_REPOS):latest $(BUILD_ARGS) .

################################################################################
# Docker Compose Target
################################################################################

.PHONY: up
up: down
	@$(RUN_ARGS) docker-compose up -d

.PHONY: down
down:
ifneq (x$(shell docker-compose --log-level ERROR ps -q),x)
	@docker-compose down
endif

################################################################################
# Cleanup Target
################################################################################

.PHONY: clean
clean: down
	@rm -rf $(CURDIR)/bin
	@docker system prune -f
	@docker volume prune -f
