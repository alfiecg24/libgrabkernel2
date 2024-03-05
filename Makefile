CC := gcc

CFLAGS ?= -Wall -Werror -Wno-unused-command-line-argument -Iinclude -I_external/include -fPIC -fobjc-arc -O3 -framework Foundation -framework Security -framework UIKit
LDFLAGS ?= -L_external/lib -lfragmentzip -lcurl -lz

LIB_NAME := libgrabkernel2

CFLAGS += -arch arm64 -arch arm64e -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=14.0
BUILD_DIR := build
OUTPUT_DIR := output

SRC_DIR := src

HEADER_OUTPUT_DIR := $(OUTPUT_DIR)/include

LIB_DIR := $(OUTPUT_DIR)/lib

STATIC_LIB := $(LIB_DIR)/$(LIB_NAME).a
DYNAMIC_LIB := $(LIB_DIR)/$(LIB_NAME).dylib

SRC_FILES := $(wildcard $(SRC_DIR)/*.m)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.m, $(BUILD_DIR)/%.o, $(SRC_FILES))

HEADER_OUTPUT_DIR := $(OUTPUT_DIR)/include

all: copy_headers $(STATIC_LIB) $(DYNAMIC_LIB)

$(STATIC_LIB): $(OBJ_FILES)
	@mkdir -p $(LIB_DIR)
	libtool $^ -o $@

$(DYNAMIC_LIB): $(OBJ_FILES)
	@mkdir -p $(LIB_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o $@ $^
	@ldid -S $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.m
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) $(LDFLAGS) -c $< -o $@

copy_headers:
	@mkdir -p $(HEADER_OUTPUT_DIR)
	@cp -r include/grabkernel.h $(HEADER_OUTPUT_DIR)/libgrabkernel2.h

clean:
	@rm -rf $(BUILD_DIR) $(OUTPUT_DIR)