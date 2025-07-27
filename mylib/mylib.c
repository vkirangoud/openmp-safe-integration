#include <omp.h>
#include <stdio.h>

void mylib_hello() {
    #pragma omp parallel
    {
        int tid = omp_get_thread_num();
        printf("[mylib] Hello from thread %d\n", tid);
    }
}
