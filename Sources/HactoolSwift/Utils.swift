import Foundation

// MARK: - Global Type Alias for Data Provider
typealias DataProvider = (UInt64, Int) throws -> Data

/// Reads a UInt32 from the buffer and interprets it as a 4-character ASCII string.
/// - Parameters:
///   - buffer: The UnsafeRawBufferPointer to read from.
///   - offset: The byte offset to start reading.
/// - Returns: An optional String. Returns nil if the bytes do not form a valid ASCII string.
/// - Throws: A ParserError if reading is out of bounds.
func readMagic(from buffer: UnsafeRawBufferPointer, at offset: Int) throws -> String? {
    // 1. Use our trusted readLE function to get the 32-bit integer
    let magicRaw: UInt32 = try readLE(from: buffer, at: offset)
    
    // 2. We need to get the raw bytes of this integer to convert it to a String.
    //    withUnsafeBytes is a safe way to do this.
    var magicForData = magicRaw
    let magicData = withUnsafeBytes(of: &magicForData) { Data($0) }
    
    // 3. Attempt to create a String from these bytes using ASCII encoding.
    return String(data: magicData, encoding: .ascii)
}

// MARK: - Global Parsing Helpers
// 在你的项目中，找到并替换/定义 readLE 函数
// 这是最终的、最安全、最兼容的版本，使用内存复制来解决对齐问题。
func readLE<T: FixedWidthInteger>(from buffer: UnsafeRawBufferPointer, at offset: Int) throws -> T {
    let size = MemoryLayout<T>.size
    guard offset >= 0 && offset + size <= buffer.count else {
        throw ParserError.dataOutOfBounds(reason: "Read for \(T.self) at offset \(offset) out of bounds for buffer size \(buffer.count).")
    }

    // 1. 创建一个正确类型的、未初始化的变量。
    //    由于它是在栈上创建的，Swift 保证它的地址是对齐的。
    var value: T = 0
    
    // 2. 使用 withUnsafeMutableBytes 安全地获取这个变量的可变字节指针，这就是我们的目标缓冲区。
    withUnsafeMutableBytes(of: &value) { destinationBuffer in
        // 3. 计算源指针在 buffer 中的起始位置。
        let sourceBuffer = UnsafeRawBufferPointer(rebasing: buffer[offset..<(offset + size)])
        
        // 4. 使用 memcpy 的 Swift 版本，将字节从源 buffer 复制到我们的目标变量中。
        //    这个操作是逐字节复制，完全不关心源地址的对齐问题。
        destinationBuffer.copyBytes(from: sourceBuffer)
    }
    
    // 5. 此时 value 变量中已经包含了内存中的小端字节序数据，现在进行字节序转换。
    return T(littleEndian: value)
}

// MARK: - Error Handling
enum ParserError: Error, LocalizedError, Equatable {
    case fileTooShort(reason: String)
    case invalidMagic(expected: String, found: String)
    case dataOutOfBounds(reason: String)
    case unknownFormat(String)
    case general(String)
    
    var errorDescription: String? {
        switch self {
        case .general(let reason):
            return "Parser gernal error \(reason)"
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
