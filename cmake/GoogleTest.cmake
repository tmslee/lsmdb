include(FetchContent)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.15.2
    FIND_PACKAGE_ARGS  # Prefer system-installed if available
)

# Suppress GoogleTest installation
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(googletest)

# note: FIND_PACKAGE_ARGS (CMake 3.24+) tries find_package(GTest) first, falling back to download. 
# This respects system packages in CI/containers while still working on a fresh machine. 
# INSTALL_GTEST OFF prevents GoogleTest from polluting our install targets.