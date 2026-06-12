# Tactical Grid

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84.svg)](https://developer.android.com)

Tactical Grid is a high-performance **Tower Defense Game** built with Flutter and Flame engine, featuring a native Android C++ game engine with OpenGL ES rendering.

---

## Features

- **Native C++ Game Engine**: Core gameplay, pathfinding, and rendering written in C++ for maximum performance
- **OpenGL ES Renderer**: Custom batched 2D renderer for smooth graphics on Android
- **Hybrid Architecture**: Flutter/Dart for UI and overlays, native C++ for core game logic
- **FFI Integration**: Zero-copy state sync between native code and Flutter via Dart FFI
- **Tower Defense Gameplay**:
  - Multiple tower types with unique abilities
  - Enemy waves with varied behaviors
  - Multiple map layouts
  - Upgrade and strategy mechanics
- **Audio System**: Native audio events consumed by Flutter for sound effects

---

## Architecture

The project follows a hybrid architecture:

```
Tactical Grid/
├── lib/                          # Flutter/Dart layer
│   ├── src/features/game/        # Game controller, models, FFI bindings
│   └── src/features/shell/       # UI screens, menus, overlays
├── android/app/src/main/
│   ├── cpp/engine/               # Native C++ game engine
│   │   ├── runtime/              # Game logic, pathfinding, entities
│   │   ├── rendering/            # OpenGL ES renderer
│   │   └── content/              # Tower/enemy definitions
│   └── kotlin/                   # Android host integration
```

| Layer | Technology | Responsibility |
|-------|------------|----------------|
| UI | Flutter/Dart | Menus, overlays, game screen, audio consumption |
| Game Engine | C++/NDK | Core simulation, pathfinding, tower/enemy logic |
| Rendering | OpenGL ES | Batched 2D graphics, vertex colors |
| Platform | Kotlin/JNI | Android lifecycle, touch input, FFI bridge |

---

## Getting Started

### Prerequisites

- **Flutter SDK**: `^3.9.2`
- **Dart SDK**: `^3.9.2`
- **Android NDK**: Required for native C++ compilation
- **CMake**: For native build configuration
- **Android Studio** or VS Code with Flutter/C++ extensions

### Setup & Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/bala2006/Tactical-Grid.git
   cd Tactical-Grid
   ```

2. **Fetch Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Configure Android NDK** (if not already configured):
   - Open `android/local.properties`
   - Add: `ndk.dir=/path/to/your/ndk`

4. **Build the APK**:
   ```bash
   flutter build apk --debug
   ```

5. **Run on Device/Emulator**:
   ```bash
   flutter run
   ```

---

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run tests (if available)
flutter test

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Run analysis: `flutter analyze`
5. Commit and push
6. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Flame](https://flame-engine.org/) - Flutter game engine
- [dart:ffi](https://dart.dev/guides/libraries/c-interop) - Foreign function interface
- OpenGL ES for native rendering capabilities

---

## Support

If you find this project useful, please consider starring the repository!

For issues, feature requests, or questions, please open an issue on GitHub.