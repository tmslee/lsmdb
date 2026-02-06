include(FetchContent)

FetchContent_Declare(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 11.1.4
)

FetchContent_MakeAvailable(fmt)

# note: {fmt} is the reference implementation that std::format (C++20) was based on.
# GCC 11 / Clang 14 don't ship std::format yet (requires GCC 13+ / Clang 17+).
# When compilers are upgraded, switching from fmt::format to std::format is trivial.
# Many production codebases (including Google's) use {fmt} regardless of compiler version
# because it compiles faster and has more features than std::format.
