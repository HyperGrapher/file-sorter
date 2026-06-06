CC ?= cc
CFLAGS ?= -Wall -Wextra -pedantic -std=c99 -O2
TARGET ?= filesorter

ifeq ($(OS),Windows_NT)
TARGET := filesorter.exe
endif

.PHONY: all clean

all: $(TARGET)

$(TARGET): file_sorter.c
	$(CC) $(CFLAGS) -o $(TARGET) file_sorter.c

clean:
	rm -f filesorter filesorter.exe
