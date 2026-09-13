# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.22)
project(qtac-napi)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Detect if we're being built standalone (cmake-js) or as part of main project
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(STANDALONE_BUILD TRUE)
    # When built standalone, find the repository root
    get_filename_component(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
else()
    set(STANDALONE_BUILD FALSE)
    set(REPO_ROOT ${CMAKE_SOURCE_DIR})
endif()

message(STATUS "Standalone build: ${STANDALONE_BUILD}")
message(STATUS "Repository root: ${REPO_ROOT}")

# Find Node.js and node-addon-api
execute_process(
    COMMAND node -p "require('node-addon-api').include"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE NODE_ADDON_API_DIR
    OUTPUT_STRIP_TRAILING_WHITESPACE
    RESULT_VARIABLE NODE_ADDON_API_RESULT
)

if(NOT NODE_ADDON_API_RESULT EQUAL 0)
    message(FATAL_ERROR "node-addon-api not found. Run 'npm install' in interfaces/Node.js/")
endif()

execute_process(
    COMMAND node -p "process.versions.node"
    OUTPUT_VARIABLE NODE_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

message(STATUS "Building NAPI module for Node.js ${NODE_VERSION}")
message(STATUS "node-addon-api include: ${NODE_ADDON_API_DIR}")

# Define NAPI module target
add_library(qtac_napi SHARED
    src/addon.cc
    src/tacdev_wrapper.cc
    src/utils.cc
)

# Set output name to qtac.node
set_target_properties(qtac_napi PROPERTIES
    PREFIX ""
    SUFFIX ".node"
    OUTPUT_NAME "qtac"
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

# Include directories
target_include_directories(qtac_napi PRIVATE
    ${NODE_ADDON_API_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${REPO_ROOT}/interfaces/C++/TACDev
    ${REPO_ROOT}/src/libraries/qcommon-console
)

# Find TACDev library
if(STANDALONE_BUILD)
    # In standalone mode, find the pre-built TACDev library
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(TACDEV_LIB_NAME "TACDevd")
    else()
        set(TACDEV_LIB_NAME "TACDev")
    endif()

    # Detect architecture
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "ARM64|aarch64")
        set(BUILD_ARCH "ARM64")
    elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(BUILD_ARCH "Linux")
    else()
        set(BUILD_ARCH "x64")
    endif()

    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(BUILD_CONFIG "Debug")
    else()
        set(BUILD_CONFIG "Release")
    endif()

    # Look for TACDev library in build output (static library)
    set(TACDEV_LIB_PATH "${REPO_ROOT}/__Builds/${BUILD_ARCH}/${BUILD_CONFIG}")

    if(WIN32)
        set(TACDEV_LIB_FILE "${TACDEV_LIB_PATH}/lib/${TACDEV_LIB_NAME}.lib")
    else()
        set(TACDEV_LIB_FILE "${TACDEV_LIB_PATH}/lib/lib${TACDEV_LIB_NAME}.a")
    endif()

    message(STATUS "Looking for TACDev library at: ${TACDEV_LIB_FILE}")

    if(NOT EXISTS "${TACDEV_LIB_FILE}")
        message(FATAL_ERROR "TACDev library not found at ${TACDEV_LIB_FILE}. Please build the main QTAC project first using build.bat or build.sh")
    endif()

    # Create imported target for static library
    add_library(TACDev STATIC IMPORTED)
    set_target_properties(TACDev PROPERTIES
        IMPORTED_LOCATION "${TACDEV_LIB_FILE}"
    )

    target_link_libraries(qtac_napi PRIVATE TACDev)

    # Since TACDev is static, we need to link its dependencies
    # Find Qt6 packages that TACDev depends on
    find_package(Qt6 COMPONENTS Core SerialPort QUIET)
    if(Qt6_FOUND)
        message(STATUS "Found Qt6 for transitive dependencies")
        target_link_libraries(qtac_napi PRIVATE Qt6::Core Qt6::SerialPort)
    else()
        message(WARNING "Qt6 not found - NAPI module may have unresolved symbols at runtime")
    endif()
else()
    # In integrated build, link against the target
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        target_link_libraries(qtac_napi PRIVATE TACDevd)
    else()
        target_link_libraries(qtac_napi PRIVATE TACDev)
    endif()
endif()

# Platform-specific settings
if(WIN32)
    target_compile_definitions(qtac_napi PRIVATE
        NAPI_VERSION=8
        WIN32_LEAN_AND_MEAN
        NOMINMAX
    )

    # Suppress node-gyp warnings
    target_compile_options(qtac_napi PRIVATE
        /wd4251  # class needs to have dll-interface
        /wd4275  # non dll-interface class used as base
    )
elseif(UNIX)
    target_compile_definitions(qtac_napi PRIVATE
        NAPI_VERSION=8
    )

    target_link_libraries(qtac_napi PRIVATE
        ${CMAKE_DL_LIBS}
    )

    target_compile_options(qtac_napi PRIVATE
        -fexceptions
        -Wno-unused-result
    )
endif()

# Install to build directory for npm to find
install(TARGETS qtac_napi
    LIBRARY DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/build/Release
    RUNTIME DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/build/Release
)
