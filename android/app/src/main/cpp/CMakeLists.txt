# For more information about using CMake with Android Studio, read the
# documentation: https://d.android.com/studio/projects/add-native-code.html

cmake_minimum_required(VERSION 3.22.1)

project("towerdefense")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Creates your game shared library. The name must be the same as the
# one used for loading in your Kotlin/Java or AndroidManifest.txt files.
add_library(towerdefense SHARED
        engine/runtime/NativeBridge.cpp
        engine/runtime/NativeEngine.cpp
        engine/content/EnemyArchetypes.cpp
        engine/content/EnemyBehaviors.cpp
        engine/systems/EnemySystem.cpp
        engine/systems/ProjectileSystem.cpp
        engine/systems/TowerSystem.cpp
        engine/content/TowerCatalog.cpp
        engine/content/TowerUpgrades.cpp
        engine/systems/WaveRuntime.cpp
        engine/rendering/GlRenderer2D.cpp)

target_include_directories(towerdefense PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/engine/runtime
        ${CMAKE_CURRENT_SOURCE_DIR}/engine/domain
        ${CMAKE_CURRENT_SOURCE_DIR}/engine/systems
        ${CMAKE_CURRENT_SOURCE_DIR}/engine/content
        ${CMAKE_CURRENT_SOURCE_DIR}/engine/rendering)

# Configure libraries CMake uses to link your target library.
target_link_libraries(towerdefense
        GLESv3
        android
        log)
