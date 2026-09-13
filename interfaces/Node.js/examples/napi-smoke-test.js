// Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
// SPDX-License-Identifier: BSD-3-Clause

// Direct N-API smoke test. This bypasses the TypeScript wrapper so that the
// native qtac.node module can be tested independently.
const native = require('./qtac-native').native;
const TACDevice = native.TACDevice;

function check(condition, message) {
    if (!condition) {
        throw new Error(`N-API check failed: ${message}`);
    }
}

function main() {
    console.log('=== QTAC N-API Smoke Test ===\n');

    check(TACDevice, 'TACDevice export is missing');
    check(typeof TACDevice.InitializeTACDev === 'function', 'InitializeTACDev is missing');
    check(typeof TACDevice.GetDeviceCount === 'function', 'GetDeviceCount is missing');
    check(typeof TACDevice.GetPortData === 'function', 'GetPortData is missing');

    const initResult = TACDevice.InitializeTACDev();
    console.log('InitializeTACDev:', initResult);

    console.log('Alpaca version:', TACDevice.GetAlpacaVersion());
    console.log('TAC version:   ', TACDevice.GetTACVersion());
    console.log('Logging state: ', TACDevice.GetLoggingState());

    const count = TACDevice.GetDeviceCount();
    check(Number.isInteger(count) && count >= 0, 'invalid device count');
    console.log(`Devices found:  ${count}\n`);

    for (let index = 0; index < count; index += 1) {
        const info = TACDevice.GetPortData(index);
        console.log(`Device ${index}:`, info);

        // Read-only calls exercise construction, native handle ownership, and
        // the device information N-API methods without changing device state.
        const device = TACDevice.OpenHandleByDescription(info.port);
        try {
            console.log('  Handle:           ', device.getHandle());
            console.log('  Name:             ', device.getName());
            console.log('  Firmware:         ', device.getFirmwareVersion());
            console.log('  Hardware:         ', device.getHardware());
            console.log('  Hardware version: ', device.getHardwareVersion());
            console.log('  UUID:             ', device.getUUID());
        } finally {
            device.close();
            console.log('  Closed.\n');
        }
    }

    if (count === 0) {
        console.log('No TAC devices connected; native initialization and enumeration passed.');
    }

    console.log('\nN-API smoke test passed.');
}

try {
    main();
} catch (error) {
    console.error('\nN-API smoke test failed:', error.message);
    if (error.stack) {
        console.error(error.stack);
    }
    process.exitCode = 1;
}
