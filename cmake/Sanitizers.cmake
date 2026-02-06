function(lsmdb_set_sanitizer target)
    if(NOT DEFINED LSMDB_SANITIZER)
        return()
    endif()

    if(LSMDB_SANITIZER STREQUAL "address")
        target_compile_options(${target} PUBLIC -fsanitize=address -fno-omit-frame-pointer)
        target_link_options(${target} PUBLIC -fsanitize=address)
    elseif(LSMDB_SANITIZER STREQUAL "thread")
        target_compile_options(${target} PUBLIC -fsanitize=thread)
        target_link_options(${target} PUBLIC -fsanitize=thread)
    elseif(LSMDB_SANITIZER STREQUAL "undefined")
        target_compile_options(${target} PUBLIC -fsanitize=undefined -fno-sanitize-recover=all)
        target_link_options(${target} PUBLIC -fsanitize=undefined -fno-sanitize-recover=all)
    elseif(LSMDB_SANITIZER STREQUAL "fuzzer")
        target_compile_options(${target} PUBLIC -fsanitize=fuzzer,address -fno-omit-frame-pointer)
        target_link_options(${target} PUBLIC -fsanitize=fuzzer,address)
    else()
        message(FATAL_ERROR "Unknown sanitizer: ${LSMDB_SANITIZER}")
    endif()
endfunction()

# note: Sanitizers are applied per-target with PUBLIC visibility so they propagate to tests that link against the library. 
# -fno-sanitize-recover=all on UBSan makes it abort on the first violation instead of continuing — you want hard failures in CI. 
# The fuzzer preset combines libFuzzer with ASan because most fuzz bugs are memory errors.