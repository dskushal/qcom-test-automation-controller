// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <napi.h>
#include <string>
#include <functional>
#include "TACDev.h"

namespace qtac_napi {

/**
 * Get the last error message from TACDev library
 */
std::string GetLastErrorMessage();

/**
 * Throw a JavaScript exception based on TAC_ERROR code
 */
void ThrowTACError(const Napi::Env& env, TAC_ERROR error, const std::string& context = "");

/**
 * Call a TACDev function that returns a string
 * Handles buffer allocation and automatic retry if buffer is too small
 */
bool CallStringFunction(
    const Napi::Env& env,
    std::function<TAC_ERROR(char*, int)> func,
    std::string& output,
    const std::string& context,
    int initialBufferSize = 256
);

/**
 * Call a TACDev function that returns a string with handle parameter
 */
bool CallStringFunctionWithHandle(
    const Napi::Env& env,
    TAC_HANDLE handle,
    std::function<TAC_ERROR(TAC_HANDLE, char*, int)> func,
    std::string& output,
    const std::string& context,
    int initialBufferSize = 256
);

/**
 * Parse semicolon-delimited device info string
 * Format: "port;description;serialNumber;index"
 */
Napi::Object ParseDeviceInfo(const Napi::Env& env, const std::string& data);

/**
 * Parse semicolon-delimited command metadata string
 * Format: "command;helpText;pin;tabName;groupName;cellLocation"
 */
Napi::Object ParseCommandMetadata(const Napi::Env& env, const std::string& data);

/**
 * Validate TAC_HANDLE is not kBadHandle
 */
void ValidateHandle(const Napi::Env& env, TAC_HANDLE handle);

} // namespace qtac_napi
