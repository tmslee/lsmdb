cmake_minimum_required(VERSION 3.22)
project(lsmdb
    VERSION 0.1.0
    LANGUAGES CXX
    DESCRIPTION "LSM-tree based embedded key-value storage engine"
)

# ── C++20 Standard ──────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ── CMake Modules ───────────────────────────────────────────────
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(CompilerWarnings)
include(Sanitizers)
include(Fmt)

# ── Library Target ──────────────────────────────────────────────
add_library(lsmdb STATIC)
add_library(lsmdb::lsmdb ALIAS lsmdb)

target_sources(lsmdb PRIVATE
    src/lsmdb.cpp  # Placeholder — replaced as components are implemented
)

target_include_directories(lsmdb
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
)

target_link_libraries(lsmdb PUBLIC fmt::fmt)

lsmdb_set_warnings(lsmdb)
lsmdb_set_sanitizer(lsmdb)

# ── Testing ─────────────────────────────────────────────────────
if(BUILD_TESTING)
    include(GoogleTest)
    include(CTest)
    add_subdirectory(test)
endif()

#note: add_library(lsmdb::lsmdb ALIAS ...) creates a namespaced alias — this is modern CMake best practice so consumers can target_link_libraries(app PRIVATE lsmdb::lsmdb) with the same syntax whether it's a subdirectory or an installed package. 
# Generator expressions ($<BUILD_INTERFACE:...>) ensure include paths work correctly for both building and installing.