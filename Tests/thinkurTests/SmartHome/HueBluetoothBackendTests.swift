import Foundation
import Testing
@testable import thinkur

@Suite("HueBluetoothBackend TLV encoding")
struct HueBluetoothBackendTests {

    @Test("TLV on command is correct bytes")
    func tlvOn() {
        let data = HueBluetoothBackend.buildTLVOn()
        #expect(data == Data([0x01, 0x01, 0x01]))
    }

    @Test("TLV off command is correct bytes")
    func tlvOff() {
        let data = HueBluetoothBackend.buildTLVOff()
        #expect(data == Data([0x01, 0x01, 0x00]))
    }

    @Test("TLV brightness encodes 0 percent to 0")
    func tlvBrightnessZero() {
        let data = HueBluetoothBackend.buildTLVBrightness(percent: 0)
        #expect(data == Data([0x02, 0x01, 0]))
    }

    @Test("TLV brightness encodes 100 percent to 254")
    func tlvBrightnessFull() {
        let data = HueBluetoothBackend.buildTLVBrightness(percent: 100)
        #expect(data == Data([0x02, 0x01, 254]))
    }

    @Test("TLV brightness encodes 50 percent to 127")
    func tlvBrightnessHalf() {
        let data = HueBluetoothBackend.buildTLVBrightness(percent: 50)
        #expect(data == Data([0x02, 0x01, 127]))
    }

    @Test("TLV brightness clamps negative to 0")
    func tlvBrightnessClampLow() {
        let data = HueBluetoothBackend.buildTLVBrightness(percent: -10)
        #expect(data == Data([0x02, 0x01, 0]))
    }

    @Test("TLV brightness clamps above 100 to 254")
    func tlvBrightnessClampHigh() {
        let data = HueBluetoothBackend.buildTLVBrightness(percent: 200)
        #expect(data == Data([0x02, 0x01, 254]))
    }

    @Test("TLV commands have correct type bytes")
    func tlvTypeBytes() {
        let onData = HueBluetoothBackend.buildTLVOn()
        let brightnessData = HueBluetoothBackend.buildTLVBrightness(percent: 75)

        // Power commands use type 0x01
        #expect(onData[0] == 0x01)
        // Brightness commands use type 0x02
        #expect(brightnessData[0] == 0x02)
    }

    @Test("TLV commands all have length byte of 1")
    func tlvLengthBytes() {
        let on = HueBluetoothBackend.buildTLVOn()
        let off = HueBluetoothBackend.buildTLVOff()
        let brightness = HueBluetoothBackend.buildTLVBrightness(percent: 50)

        #expect(on[1] == 0x01)
        #expect(off[1] == 0x01)
        #expect(brightness[1] == 0x01)
    }
}
