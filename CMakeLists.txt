cmake_minimum_required(VERSION 3.25)

project(ladybird-appkit
    VERSION 0.0.1
    LANGUAGES CXX
    DESCRIPTION "Ladybird Web Browser"
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

list(APPEND CMAKE_MODULE_PATH "$ENV{SERENITY_SOURCE_DIR}/Meta/CMake")
include(Meta/CMake/Lagom.cmake)
include(lagom_compile_options NO_POLICY_SCOPE)

find_library(COCOA_LIBRARY Cocoa)

add_executable(Ladybird MACOSX_BUNDLE
    main.mm
    Application/ApplicationDelegate.mm
    UI/Tab.mm
    UI/TabController.mm
)

target_compile_options(Ladybird PRIVATE -DAK_DONT_REPLACE_STD -DUSING_AK_GLOBALLY=0 -fobjc-arc)
target_link_libraries(Ladybird PRIVATE LibCore ${COCOA_LIBRARY})
target_include_directories(Ladybird PRIVATE .)
