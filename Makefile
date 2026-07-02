# local-chat-ios — Development Makefile
# Build & Install LLM inference bench on test devices

DEVICE_14PLUS := 00008110-00067D861486201E
DEVICE_15     := 00008120-000260903ED1A01E
DEVICE ?= 14plus
PROJECT ?= local-chat-ios.xcodeproj
SCHEME  ?= local-chat-ios

DERIVED_DATA := $(HOME)/Library/Developer/Xcode/DerivedData/local-chat-ios-fxyknirtzrurysazzldhiwnfffog
APP_PATH     := $(DERIVED_DATA)/Build/Products/Debug-iphoneos/local-chat-ios.app

.PHONY: build install deploy clean

build:  ## Build for device
ifeq ($(DEVICE),15)
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination "platform=iOS,id=$(DEVICE_15)" \
		-configuration Debug build 2>&1 | tail -5
else
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination "platform=iOS,id=$(DEVICE_14PLUS)" \
		-configuration Debug build 2>&1 | tail -5
endif

install:  ## Install on device
ifeq ($(DEVICE),15)
	@xcrun devicectl device install app --device $(DEVICE_15) "$(APP_PATH)"
else
	@xcrun devicectl device install app --device $(DEVICE_14PLUS) "$(APP_PATH)"
endif

deploy: build install  ## Build + Install

clean:  ## Clean DerivedData
	@rm -rf $(DERIVED_DATA)
	@echo "Cleaned."
