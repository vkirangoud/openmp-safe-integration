#include <omp.h>
#include <stdio.h>

int main() {
    printf("OpenMP version: %d\n", _OPENMP);
    omp_display_env(1);  // Intel's will show detailed info
    return 0;
}
