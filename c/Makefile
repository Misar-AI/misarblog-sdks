CC      = gcc
CFLAGS  = -Wall -Wextra -I./include
LIBS    = -lcurl
SRC     = src/misarblog.o
TARGET  = libmisarblog.a

all: $(TARGET)

$(TARGET): $(SRC)
	ar rcs $@ $^

src/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f src/*.o $(TARGET)

.PHONY: all clean
