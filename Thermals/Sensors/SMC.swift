import Foundation
import IOKit

struct FanReading: Identifiable, Equatable {
    let id: Int
    /// Nil when the SMC refused the read; the board shows unavailable rather than a guess.
    let rpm: Double?
    let minimum: Double?
    let maximum: Double?

    /// How far the fan is through its range, 0 at minimum and 1 at maximum; nil without a usable range.
    var fraction: Double? {
        guard let rpm, let minimum, let maximum, maximum > minimum else { return nil }
        return min(1, max(0, (rpm - minimum) / (maximum - minimum)))
    }
}

/// Fan speeds (`FNum`, `F<n>Ac`, `F<n>Mn`, `F<n>Mx`) and system power (`PSTR`) from the System Management Controller. Fanless Macs report no fans.
final class SMCReader {
    private let connection: io_connect_t

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess else { return nil }
        self.connection = connection
    }

    deinit {
        IOServiceClose(connection)
    }

    func fans() -> [FanReading] {
        guard let count = value("FNum"), let fans = SMC.fanCount(count) else { return [] }
        return (0..<fans).map { fan in
            FanReading(id: fan + 1, rpm: rpm("F\(fan)Ac"), minimum: rpm("F\(fan)Mn"), maximum: rpm("F\(fan)Mx"))
        }
    }

    /// Whole-system power in watts; nil when the key is missing or implausible.
    func systemPower() -> Double? {
        value("PSTR").flatMap(SMC.plausibleWatts)
    }

    private func rpm(_ key: String) -> Double? {
        value(key).flatMap(SMC.plausibleRPM)
    }

    private func value(_ key: String) -> Double? {
        guard let code = SMC.fourCharCode(key) else { return nil }
        var input = SMCParams()
        input.key = code
        input.data8 = SMC.getKeyInfo
        guard let info = call(&input), info.result == 0 else { return nil }
        input.keyInfo = info.keyInfo
        input.data8 = SMC.readKey
        guard let output = call(&input), output.result == 0 else { return nil }
        let bytes = withUnsafeBytes(of: output.bytes) { Array($0.prefix(Int(info.keyInfo.dataSize))) }
        return SMC.decode(bytes, type: info.keyInfo.dataType)
    }

    private func call(_ input: inout SMCParams) -> SMCParams? {
        var output = SMCParams()
        var outputSize = MemoryLayout<SMCParams>.stride
        let result = IOConnectCallStructMethod(connection, SMC.handleEvent, &input, MemoryLayout<SMCParams>.stride, &output, &outputSize)
        return result == kIOReturnSuccess && outputSize == MemoryLayout<SMCParams>.stride ? output : nil
    }
}

/// The SMC user client's 80-byte parameter block. Swift places fields after the previous field's size, not its stride,
/// so the key info carries its C padding explicitly.
struct SMCParams {
    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var attributes: UInt8 = 0
        var padding: (UInt8, UInt8, UInt8) = (0, 0, 0)
    }

    var key: UInt32 = 0
    var version: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
    var powerLimits: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
    var keyInfo = KeyInfo()
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
}

enum SMC {
    static let handleEvent: UInt32 = 2
    static let readKey: UInt8 = 5
    static let getKeyInfo: UInt8 = 9
    static let float = fourCharCode("flt ")!
    static let fixedPoint = fourCharCode("fpe2")!
    static let uint8 = fourCharCode("ui8 ")!
    static let uint16 = fourCharCode("ui16")!

    /// A whole fan count no Mac exceeds; anything else means the key can't be trusted.
    static func fanCount(_ value: Double) -> Int? {
        (0...8).contains(value) && value == value.rounded() ? Int(value) : nil
    }

    static func plausibleRPM(_ value: Double) -> Double? {
        (0...20_000).contains(value) ? value : nil
    }

    /// A Mac draws some power while it runs, and none draws 500 W; zero means the key isn't measuring.
    static func plausibleWatts(_ value: Double) -> Double? {
        value > 0 && value < 500 ? value : nil
    }

    static func fourCharCode(_ text: String) -> UInt32? {
        let scalars = Array(text.unicodeScalars)
        guard scalars.count == 4, scalars.allSatisfy(\.isASCII) else { return nil }
        return scalars.reduce(0) { $0 << 8 | $1.value }
    }

    /// Decodes the value types fan and power keys use; anything else is nil rather than a guess.
    static func decode(_ bytes: [UInt8], type: UInt32) -> Double? {
        switch type {
        case float:
            guard bytes.count == 4 else { return nil }
            let value = Double(Float(bitPattern: UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24))
            return value.isFinite ? value : nil
        case fixedPoint:
            guard bytes.count == 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4
        case uint8:
            return bytes.count == 1 ? Double(bytes[0]) : nil
        case uint16:
            guard bytes.count == 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        default:
            return nil
        }
    }
}
