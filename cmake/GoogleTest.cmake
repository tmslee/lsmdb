include(FetchContent)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.15.2
)

# Suppress GoogleTest installation
set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(googletest)

# note: FIND_PACKAGE_ARGS would let CMake try find_package(GTest) first before downloading,
# but it requires CMake 3.24+. With our 3.22 minimum, FetchContent always downloads.
# INSTALL_GTEST OFF prevents GoogleTest from polluting our install targets.