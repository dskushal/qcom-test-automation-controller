# Building the Node.js NAPI Interface

## Prerequisites

1. **Build the main QTAC project first**
   
   The Node.js interface depends on the TACDev C++ library, which must be built before the NAPI module can be compiled.

   ### Windows:
   ```cmd
   # From repository root
   .\build.bat
   ```

   ### Linux:
   ```bash
   # From repository root
   ./build.sh
   ```

   This will build TACDev library to:
   - Windows x64: `__Builds/x64/Release/bin/TACDev.dll`
   - Windows ARM64: `__Builds/ARM64/Release/bin/TACDev.dll`
   - Linux: `__Builds/Linux/Release/lib/libTACDev.so`

2. **Node.js 18 or higher**
   ```bash
   node --version  # Should be >= 18.0.0
   ```

3. **CMake 3.22 or higher**
   ```bash
   cmake --version
   ```

4. **C++ Build Tools**
   - Windows: Visual Studio 2022 or Build Tools for Visual Studio 2022
   - Linux: GCC 11+ or Clang

## Build Steps

Once the prerequisites are met:

```bash
cd interfaces/Node.js

# Install dependencies and build native module
npm install

# Build TypeScript layer
npm run build
```

## Troubleshooting

### Error: "TACDev library not found"

**Solution**: Build the main QTAC project first using `build.bat` (Windows) or `build.sh` (Linux) from the repository root.

### Error: "node-addon-api not found"

**Solution**: Run `npm install` to install Node.js dependencies first.

### Error: "cmake-js not found"

**Solution**: cmake-js is a devDependency. Run `npm install` first.

### Windows: "MSVC not found"

**Solution**: Install Visual Studio 2022 or Build Tools for Visual Studio 2022 with C++ desktop development workload.

### Linux: "Qt6 not found"

**Solution**: Install Qt 6.9+ development packages:
```bash
sudo apt-get install qt6-base-dev qt6-serialport-dev
```

## Verification

After successful build:

```bash
# Run unit tests
npm test:unit

# Run examples (requires TAC device)
node examples/list-devices.js
```

## Manual Build

If you need to rebuild just the native module:

```bash
npm run build:native
```

To clean and rebuild everything:

```bash
npm run clean
npm install
npm run build
```

## Development

When making changes to C++ code (`src/*.cc`):

```bash
npm run build:native  # Rebuild native module
```

When making changes to TypeScript code (`lib/*.ts`):

```bash
npm run build  # Rebuild TypeScript
```
