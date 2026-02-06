include(GoogleTest)

function(lsmdb_add_test test_name test_source)
    add_executable(${test_name} ${test_source})
    target_link_libraries(${test_name}
        PRIVATE
            lsmdb::lsmdb
            GTest::gtest_main
    )
    lsmdb_set_warnings(${test_name})
    lsmdb_set_sanitizer(${test_name})
    gtest_discover_tests(${test_name})
endfunction()

# Tests added as components are implemented

# note: gtest_discover_tests() introspects the test binary at CTest time to register each TEST() individually. 
# This means ctest -R SliceTest.Comparison works out of the box — much better than add_test() which only registers one monolithic test per binary.