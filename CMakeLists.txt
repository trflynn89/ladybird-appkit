cmake_minimum_required(VERSION 3.25)

project(ladybird-appkit
    VERSION 0.0.1
    LANGUAGES CXX
    DESCRIPTION "Ladybird Web Browser"
)

set(SERENITY_SOURCE_DIR "$ENV{SERENITY_SOURCE_DIR}")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

list(APPEND CMAKE_MODULE_PATH "${SERENITY_SOURCE_DIR}/Meta/CMake")
include(Meta/CMake/Lagom.cmake)
include(lagom_compile_options NO_POLICY_SCOPE)

find_library(COCOA_LIBRARY Cocoa)

add_executable(Ladybird MACOSX_BUNDLE
    main.mm
    Application/ApplicationDelegate.mm
    UI/Tab.mm
    UI/TabController.mm
)

target_compile_options(Ladybird PRIVATE
    -fobjc-arc
    -DAK_DONT_REPLACE_STD
    -Wno-expansion-to-defined
    -Wno-user-defined-literals
)

target_link_libraries(Ladybird PRIVATE
    LibCore
    LibFileSystem
    LibGfx
    LibGUI
    LibIPC
    LibJS
    LibProtocol
    LibSQL
    LibWeb
    LibWebView
    ladybird
    ${COCOA_LIBRARY}
)

create_ladybird_bundle(Ladybird)
