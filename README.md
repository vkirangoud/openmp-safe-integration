# openmp-safe-integration

This project demonstrates how to **safely link and run a shared library built with GCC** (and using Intel OpenMP runtime) from an **application built using Intel's compiler** — all using a single OpenMP runtime (`libiomp5.so`).

## Structure

```
openmp-safe-integration/
├── mylib/     # GCC-built shared library using Intel OpenMP
├── myapp/     # Intel-built application
├── run.sh     # Launcher with safe LD_LIBRARY_PATH
```

## Build Instructions

```bash
cd mylib
make

cd ../myapp
make
```

## Run Safely

```bash
chmod +x run.sh
./run.sh
```

Make sure to set this before building:

```bash
export INTEL_OMP_DIR=/opt/intel/oneapi/compiler/2023.2.1/linux/compiler/lib/intel64
```

## Runtime Check

```bash
ldd ./myapp/myapp
```
---

Very important and subtle question, so let’s unpack it carefully:



## ❓ **Scenario Recap**

You want to:

* ✅ Build **your library** using **GCC**, but force it to **link to Intel’s `libiomp5` (2025)**.
* ✅ Then use this library in an **application compiled with Intel 2023**, which links against **Intel `libiomp5` (2023)**.

---

## ⚠️ **Short Answer**: **No**, this is **not safe**. ❌

Mixing **different versions** of Intel’s OpenMP runtime (`libiomp5.so`) in the **same process** — even **implicitly** — will cause **conflicts, crashes, or runtime errors**.

---

## 🚨 Why This Fails

Intel's OpenMP runtime includes a **protection mechanism** that refuses to initialize `libiomp5.so` if another version is already loaded.

When both your library and your application try to bring in **different versions** (2023 and 2025), one of them will fail with an error like:

```
OMP: Error #15: Initializing libiomp5.so, but found libiomp5 already initialized.
OMP: Hint: This may be caused by linking to both Intel(R) and GNU OpenMP runtimes.
```

Even if both are Intel’s `libiomp5.so`, if they're **from different versions**, they can have:

* Different internal memory layouts
* Different function implementations
* Incompatible thread pool/task scheduler handling

---

## 🧬 What Happens Under the Hood

* OpenMP uses **global hidden state** (thread pool, task queues, binding maps).
* If `libiomp5.so` (2023) is already initialized by the application:

  * Then your library (linked to `libiomp5.so` 2025) either:

    * Crashes trying to reinitialize runtime
    * Ignores runtime completely (which breaks parallel regions)
    * Produces **wrong results** silently

---

## ✅ What *Will* Work (Safe Options)

### ✅ Option 1: **Use the Same Intel Runtime Version Everywhere**

* Compile both app and your library with **Intel 2025**, or **Intel 2023**
* Set `LD_LIBRARY_PATH` or `rpath` to ensure the correct `libiomp5.so` is loaded

### ✅ Option 2: **GCC + Intel OpenMP (Same Version Only)**

* Build your library with `gcc` (using `-fopenmp`)
* Link against **Intel's `libiomp5.so` 2023**
* Ensure your **application also links to exactly the same** `libiomp5.so` (2023)
* Do **not link or load GCC’s default `libgomp`**

> ✅ This works if you ensure the *same Intel OpenMP version* is used at runtime for both.

---

## ❌ What Will Not Work

| Library Build           | App Build  | Linked Runtimes                       | Result                  |
| ----------------------- | ---------- | ------------------------------------- | ----------------------- |
| GCC + `libiomp5 (2025)` | Intel 2023 | `libiomp5 (2025)` + `libiomp5 (2023)` | ❌ Crash                 |
| GCC + `libgomp`         | Intel 2023 | `libgomp` + `libiomp5`                | ❌ Crash / wrong results |
| Intel 2025              | Intel 2023 | `libiomp5` (mixed)                    | ❌ Protected crash       |

---

## 🔐 How to Ensure Correct Runtime

Use `ldd` to verify what your app and library link to:

```bash
ldd ./my_app
ldd ./my_library.so
```

Also, use `check_libiomp5_usage.sh` (from earlier) to inspect version and path of `libiomp5.so`.

---

## 🛠 Recommendation

To make your setup safe and future-proof:

* 🔒 **Standardize on one Intel compiler version** (e.g., 2025)
* 📦 Bundle or deploy with one `libiomp5.so` only
* 📁 Set `LD_LIBRARY_PATH` to ensure only one version is used
* 📄 Use `rpath` or `LD_PRELOAD` if you're shipping `.so` files with your app

---

Perfect! Here's an upgraded solution that does **two things**:

---

## ✅ What This Tool Does

1. **Lists all `libiomp5.so` copies** on your system (as before).
2. **Identifies which one is actually loaded** by your target binary (e.g. `./your_app`).

---

## 📦 Full Tool: `check_libiomp5_usage.sh`

```bash
#!/bin/bash
# Script: check_libiomp5_usage.sh
# Usage: ./check_libiomp5_usage.sh <your_binary>
# Purpose:
#  - Finds all libiomp5.so versions on the system
#  - Shows which version your app will actually use

APP="$1"

echo "========================================="
echo "🔍 Step 1: Searching for libiomp5.so files"
echo "========================================="

LIBS=$(find /opt /usr /lib* /home "$HOME" -type f -name 'libiomp5.so*' 2>/dev/null)

if [ -z "$LIBS" ]; then
    echo "✅ No libiomp5.so found on the system."
    exit 0
fi

declare -A LOADED_PATHS

i=1
for LIB in $LIBS; do
    echo "[$i] 📁 Found: $LIB"
    VERSION=$(strings "$LIB" | grep -E 'Intel\(R\) OpenMP|OpenMP runtime' | head -1)
    BUILD=$(strings "$LIB" | grep -i 'library version' | head -1)

    if [ -z "$VERSION" ] && [ -z "$BUILD" ]; then
        echo "    ⚠️  Could not extract version info."
    else
        echo "    🔢 Version: $VERSION"
        echo "    🏗️  Build: $BUILD"
    fi
    echo
    ((i++))
done

echo "============================================="
echo "🧪 Step 2: Detecting loaded libiomp5 in binary"
echo "============================================="

if [ -z "$APP" ]; then
    echo "ℹ️  No binary given. Skipping runtime check."
    echo "👉 Usage: ./check_libiomp5_usage.sh ./your_app"
    exit 0
fi

if [ ! -x "$APP" ]; then
    echo "❌ Error: '$APP' is not a valid executable."
    exit 1
fi

LOADED=$(ldd "$APP" 2>/dev/null | grep libiomp5)

if [ -z "$LOADED" ]; then
    echo "✅ '$APP' does not link to libiomp5."
else
    echo "🔗 '$APP' is linked to:"
    echo "$LOADED" | while read -r line; do
        echo "    $line"
    done
    echo

    LIB_PATH=$(echo "$LOADED" | awk '{print $3}')
    if [ -f "$LIB_PATH" ]; then
        echo "🔍 Inspecting linked libiomp5:"
        VERSION=$(strings "$LIB_PATH" | grep -E 'Intel\(R\) OpenMP|OpenMP runtime' | head -1)
        BUILD=$(strings "$LIB_PATH" | grep -i 'library version' | head -1)

        echo "    🔢 Version: $VERSION"
        echo "    🏗️  Build: $BUILD"
    fi
fi
```

---

## 🚀 How to Use

### 🔧 Step 1: Save the Script

```bash
nano check_libiomp5_usage.sh
# Paste the code above
chmod +x check_libiomp5_usage.sh
```

### ▶️ Step 2: Run It

```bash
./check_libiomp5_usage.sh ./your_app
```

---

## 🧪 Example Output

```bash
🔍 Step 1: Searching for libiomp5.so files
[1] 📁 Found: /opt/intel/2023/lib/libiomp5.so
    🔢 Version: Intel(R) OpenMP runtime - 2023.2
    🏗️  Build: Library Version 2023.2.0

[2] 📁 Found: /opt/intel/2025/lib/libiomp5.so
    🔢 Version: Intel(R) OpenMP runtime - 2025.1
    🏗️  Build: Library Version 2025.1.0

🧪 Step 2: Detecting loaded libiomp5 in binary
🔗 './my_app' is linked to:
    libiomp5.so => /opt/intel/2025/lib/libiomp5.so (0x00007f4...)

🔍 Inspecting linked libiomp5:
    🔢 Version: Intel(R) OpenMP runtime - 2025.1
    🏗️  Build: Library Version 2025.1.0
```

---

## ✅ Result: You now know

* All installed versions of `libiomp5` on your system
* Exactly **which one your application uses**
* Whether you might be accidentally mixing versions

---



