# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause

cmake_minimum_required(VERSION 3.22)
project(interfaces VERSION 1.0 LANGUAGES C CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

find_package(QT NAMES Qt6 REQUIRED COMPONENTS Core)

qt_standard_project_setup(REQUIRES 6.9)

add_subdirectory(C++/TACDev)

# Conditionally build Node.js interface if Node.js is available
find_program(NODE_EXECUTABLE node)
if(NODE_EXECUTABLE)
    message(STATUS "Node.js found at ${NODE_EXECUTABLE}, enabling Node.js interface")
    add_subdirectory(Node.js)
else()
    message(STATUS "Node.js not found, skipping Node.js interface")
endif()
