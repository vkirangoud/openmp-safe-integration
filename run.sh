#!/bin/bash

# Point to Intel 2023 libiomp5
export LD_LIBRARY_PATH=/opt/intel/oneapi/compiler/2023.2.1/linux/compiler/lib/intel64:./mylib:$LD_LIBRARY_PATH

echo "🔗 Running safely with Intel OpenMP 2023 runtime..."
./myapp/myapp
if [ $? -eq 0 ]; then
    echo "✅ Application ran successfully."
else
    echo "❌ Application failed to run."
fi
echo "🔗 Done."