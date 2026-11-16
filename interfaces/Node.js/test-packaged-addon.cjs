// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause

'use strict';
const path = require('node:path');
const addonPath = process.argv[2];
if (!addonPath) throw new Error('Pass the path to the packaged qtac.node file.');
const { TACDevice } = require(path.resolve(addonPath));
if (!TACDevice) throw new Error('The native addon did not export TACDevice.');
for (const method of ['GetAlpacaVersion', 'GetDeviceCount']) {
    if (typeof TACDevice[method] !== 'function') {
        throw new Error('TACDevice.' + method + ' is missing.');
    }
}
TACDevice.GetAlpacaVersion();
const count = TACDevice.GetDeviceCount();
if (!Number.isInteger(count) || count < 0) {
    throw new Error('GetDeviceCount returned an invalid value: ' + count);
}
console.log('Packaged qtac.node loaded successfully; ' + count + ' device(s) found.');
