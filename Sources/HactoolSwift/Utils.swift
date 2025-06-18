import Foundation

// MARK: - Global Type Alias for Data Provider
typealias DataProvider = (UInt64, Int) throws -> Data

// MARK: - Global Parsing Helpers

/// Reads a little-endian integer of type T from a Data buffer at a specific offset.
func readLE<T: FixedWidthInteger>(from data: Data, at offset: Int) throws -> T {
    let requiredSize = MemoryLayout<T>.size
    guard offset + requiredSize <= data.count else {
        throw ParserError.dataOutOfBounds(
            reason:
                "Attempted to read \(T.self) at offset \(offset) which is out of bounds for data size \(data.count)."
        )
    }

    let bytes = data.subdata(in: offset..<(offset + requiredSize))

    var value: T = 0
    for (index, byte) in bytes.enumerated() {
        value |= T(byte) << (index * 8)
    }

    return value
}

// MARK: - Error Handling
enum ParserError: Error, LocalizedError {
    case fileTooShort(reason: String)
    case invalidMagic(expected: String, found: String)
    case dataOutOfBounds(reason: String)
    case unknownFormat(String)

    var errorDescription: String? {
        switch self {
        case .fileTooShort(let reason):
            return "File is too short. \(reason)"
        case .invalidMagic(let expected, let found):
            return "Invalid magic number. Expected '\(expected)', but found '\(found)'."
        case .dataOutOfBounds(let reason):
            return "Data read is out of bounds. \(reason)"
        case .unknownFormat(let reason):
            return "Unknown or unsupported format: \(reason)"
        }
    }
}

// MARK: - Data Hex Extension
extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }

    init?(fromHex: String) {
        let hex = fromHex.dropFirst(fromHex.hasPrefix("0x") ? 2 : 0)
        guard hex.count % 2 == 0 else { return nil }

        var data = Data(capacity: hex.count / 2)
        var i = hex.startIndex
        while i < hex.endIndex {
            let nextIndex = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let byte = UInt8(hex[i..<nextIndex], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            i = nextIndex
        }
        self = data
    }
}