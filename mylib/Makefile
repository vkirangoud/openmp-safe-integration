# mylib/Makefile
CC = gcc
CFLAGS = -fopenmp -O2 -Wall
LDFLAGS = -L$(INTEL_OMP_DIR) -liomp5
TARGET = libmylib.so

all:
	$(CC) $(CFLAGS) -fPIC -c mylib.c -o mylib.o
	$(CC) -shared -o $(TARGET) mylib.o $(LDFLAGS)

clean:
	rm -f *.o $(TARGET)
