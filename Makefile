# Copyright (c) 2019 Minoru Osuka
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# 		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VERSION ?=
GOOS ?= linux
GOARCH ?= amd64
BUILD_TAGS ?=
CGO_ENABLED ?= 0
CGO_CFLAGS ?=
CGO_LDFLAGS ?=
GO15VENDOREXPERIMENT ?= 1
BIN_EXT ?=
DOCKER_REPOSITORY ?= mosuka

GO := CGO_ENABLED=$(CGO_ENABLED) GO15VENDOREXPERIMENT=$(CGO_ENABLED) go

PACKAGES = $(shell $(GO) list ./... | grep -v '/vendor/')

PROTOBUFS = $(shell find . -name '*.proto' -print0 | xargs -0 -n1 dirname | sort --unique | grep -v /vendor/)

TARGET_PACKAGES = $(shell find . -name 'main.go' -print0 | xargs -0 -n1 dirname | sort --unique | grep -v /vendor/)

ifeq ($(VERSION),)
  VERSION = latest
endif
LDFLAGS = -ldflags "-X \"github.com/mosuka/blast/version.Version=$(VERSION)\""

ifeq ($(GOOS),windows)
  BIN_EXT = .exe
endif

.DEFAULT_GOAL := build

.PHONY: dep-init
dep-init:
	@echo ">> initialize dependencies"
	dep init

.PHONY: dep-ensure
dep-ensure:
	@echo ">> install dependencies"
	dep ensure

.PHONY: dep-update
dep-update:
	@echo ">> update dependencies"
	dep ensure -update

.PHONY: protoc
protoc:
	@echo ">> generating proto3 code"
	@for proto_dir in $(PROTOBUFS); do echo $$proto_dir; protoc --proto_path=. --proto_path=$$proto_dir --proto_path=./vendor/ --go_out=plugins=grpc:$(GOPATH)/src $$proto_dir/*.proto || exit 1; done

.PHONY: format
format:
	@echo ">> formatting code"
	@$(GO) fmt $(PACKAGES)

.PHONY: test
test:
	@echo ">> testing all packages"
	@echo "   VERSION     = $(VERSION)"
	@echo "   CGO_ENABLED = $(CGO_ENABLED)"
	@echo "   CGO_CFLAGS  = $(CGO_CFLAGS)"
	@echo "   CGO_LDFLAGS = $(CGO_LDFLAGS)"
	@echo "   BUILD_TAGS  = $(BUILD_TAGS)"
	@$(GO) test -v -tags="$(BUILD_TAGS)" $(LDFLAGS) $(PACKAGES)

.PHONY: build
build:
	@echo ">> building binaries"
	@echo "   VERSION     = $(VERSION)"
	@echo "   GOOS        = $(GOOS)"
	@echo "   GOARCH      = $(GOARCH)"
	@echo "   CGO_ENABLED = $(CGO_ENABLED)"
	@echo "   CGO_CFLAGS  = $(CGO_CFLAGS)"
	@echo "   CGO_LDFLAGS = $(CGO_LDFLAGS)"
	@echo "   BUILD_TAGS  = $(BUILD_TAGS)"
	@for target_pkg in $(TARGET_PACKAGES); do echo $$target_pkg; $(GO) build -tags="$(BUILD_TAGS)" $(LDFLAGS) -o ./bin/`basename $$target_pkg`$(BIN_EXT) $$target_pkg || exit 1; done

.PHONY: install
install:
	@echo ">> installing binaries"
	@echo "   VERSION     = $(VERSION)"
	@echo "   GOOS        = $(GOOS)"
	@echo "   GOARCH      = $(GOARCH)"
	@echo "   CGO_ENABLED = $(CGO_ENABLED)"
	@echo "   CGO_CFLAGS  = $(CGO_CFLAGS)"
	@echo "   CGO_LDFLAGS = $(CGO_LDFLAGS)"
	@echo "   BUILD_TAGS  = $(BUILD_TAGS)"
	@for target_pkg in $(TARGET_PACKAGES); do echo $$target_pkg; $(GO) install -tags="$(BUILD_TAGS)" $(LDFLAGS) $$target_pkg || exit 1; done

.PHONY: dist
dist:
	@echo ">> packaging binaries"
	@echo "   VERSION     = $(VERSION)"
	@echo "   GOOS        = $(GOOS)"
	@echo "   GOARCH      = $(GOARCH)"
	@echo "   CGO_ENABLED = $(CGO_ENABLED)"
	@echo "   CGO_CFLAGS  = $(CGO_CFLAGS)"
	@echo "   CGO_LDFLAGS = $(CGO_LDFLAGS)"
	@echo "   BUILD_TAGS  = $(BUILD_TAGS)"
	mkdir -p ./dist/$(GOOS)-$(GOARCH)/bin
	@for target_pkg in $(TARGET_PACKAGES); do echo $$target_pkg; $(GO) build -tags="$(BUILD_TAGS)" $(LDFLAGS) -o ./dist/$(GOOS)-$(GOARCH)/bin/`basename $$target_pkg`$(BIN_EXT) $$target_pkg || exit 1; done
	(cd ./dist/$(GOOS)-$(GOARCH); tar zcfv ../blast-${VERSION}.$(GOOS)-$(GOARCH).tar.gz .)

.PHONY: git-tag
git-tag:
	@echo ">> tagging github"
	@echo "   VERSION     = $(VERSION)"
ifeq ($(VERSION),$(filter $(VERSION),latest master ""))
	@echo "please specify VERSION"
else
	git tag -a $(VERSION) -m "Release $(VERSION)"
	git push origin $(VERSION)
endif

.PHONY: docker-build
docker-build:
	@echo ">> building docker container image"
	@echo "   DOCKER_REPOSITORY = $(DOCKER_REPOSITORY)"
	@echo "   VERSION           = $(VERSION)"
	docker build -t $(DOCKER_REPOSITORY)/blast:latest --build-arg VERSION=$(VERSION) .
	docker tag $(DOCKER_REPOSITORY)/blast:latest $(DOCKER_REPOSITORY)/blast:$(VERSION)

.PHONY: docker-push
docker-push:
	@echo ">> pushing docker container image"
	@echo "   DOCKER_REPOSITORY = $(DOCKER_REPOSITORY)"
	@echo "   VERSION           = $(VERSION)"
	docker push $(DOCKER_REPOSITORY)/blast:latest
	docker push $(DOCKER_REPOSITORY)/blast:$(VERSION)

.PHONY: clean
clean:
	@echo ">> cleaning binaries"
	rm -rf ./bin
	rm -rf ./data
	rm -rf ./dist
