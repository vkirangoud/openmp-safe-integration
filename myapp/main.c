#include <stdio.h>

extern void mylib_hello();

int main() {
    printf("[main] Calling library...\n");
    mylib_hello();
    return 0;
}
