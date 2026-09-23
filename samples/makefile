# ==============================================================================
# hxmaker-openfl samples — Makefile
# 兼容 macOS (含 Apple Silicon) / Windows / Linux
# ==============================================================================

# ---- 可配置变量 --------------------------------------------------------------
PLATFORM ?= html5      # 目标平台: html5 / windows / mac / android / ios ...
PORT     ?= 3678       # test 时的本地调试端口
DEBUG    ?= 1          # 1 = 调试构建(-debug)，0 = 发布构建

# ---- 平台探测：仅在 macOS 下使用 arch -x86_64 (Rosetta) ----------------------
# Windows 无 arch 命令，Linux 的 arch 含义不同，因此需区分处理
ifeq ($(OS),Windows_NT)
    RUN :=
else
    UNAME_S := $(shell uname -s 2>/dev/null)
    ifeq ($(UNAME_S),Darwin)
        RUN := arch -x86_64
    else
        RUN :=
    endif
endif

LIME := $(RUN) haxelib run lime
DEBUG_FLAG := $(if $(filter 1,$(DEBUG)),-debug,)

.DEFAULT_GOAL := build

.PHONY: test build release clean rebuild run help

# ---- 目标 --------------------------------------------------------------------

## 启动本地调试
test:
	$(LIME) test $(PLATFORM) --port=$(PORT)

## 调试构建（默认目标）
build:
	$(LIME) build $(PLATFORM) $(DEBUG_FLAG)

## 发布构建
release:
	$(LIME) build $(PLATFORM)

## 清理构建产物
clean:
	$(LIME) clean $(PLATFORM)

## 清理后重新构建
rebuild: clean build

## 构建并运行
run: build
	$(RUN) ./Export/$(PLATFORM)/bin/HxmakerOpenfl

## 显示帮助
help:
	@echo "Usage: make [target] [PLATFORM=html5] [PORT=3678] [DEBUG=1]"
	@echo ""
	@echo "Targets:"
	@echo "  test     start local debug server (lime test)"
	@echo "  build    debug build (default)"
	@echo "  release  release build"
	@echo "  clean    remove build output"
	@echo "  rebuild  clean + build"
	@echo "  run      build and run"
	@echo "  help     show this help"
