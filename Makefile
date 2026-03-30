UNAME := $(shell uname -s)

.PHONY: release-and-run build-release run-release clean

release-and-run: build-release run-release

ifeq ($(UNAME),Darwin)

build-release:
	flutter build macos --release

run-release:
	open build/macos/Build/Products/Release/yap.app

clean:
	flutter clean

else ifeq ($(OS),Windows_NT)

build-release:
	flutter build windows --release

run-release:
	start build\windows\x64\runner\Release\yap.exe

clean:
	flutter clean

else
$(error Unsupported platform: $(UNAME))
endif
