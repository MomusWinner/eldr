# Eldr - A small Vulkan Rendering Engine

## ⚠️ Development Status

**Eldr is currently under active development** and is not recommended for production use. The API may change significantly between versions.

**Platform Support Note:** Currently only Linux is supported. Windows and macOS support is planned for future releases.

##  Key Features

### Pipeline Hot Reloading
- Real-time shader and pipeline recompilation during runtime
- No application restart required for pipeline updates

### Material Code Generation
- Automatic material system generation from material structure
- Type-safe material interfaces

### Bindless Rendering
- Modern bindless resource management
- Reduced descriptor set overhead

## Vulkan Features
- Dynamic Rendering
- Descriptor Indexing
- Synchronization 2

## Getting Started

```bash
# Clone the repository
git clone https://github.com/yourusername/eldr.git
cd eldr

make gen-eldr
make gen
make run
```
