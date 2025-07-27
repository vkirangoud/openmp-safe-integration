# myapp/Makefile
CC = icx
CFLAGS = -fopenmp -O2
LDFLAGS = -L../mylib -lmylib -Wl,-rpath,../mylib

TARGET = myapp

all:
	$(CC) $(CFLAGS) main.c -o $(TARGET) $(LDFLAGS)

clean:
	rm -f $(TARGET)
