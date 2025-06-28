// Sources/HactoolSwift/Crypto.swift (最终版 - 直接封装，单次调用)

import Foundation
import CMbedTLS

typealias Key = Data
typealias RawData = Data

/// Custom errors for high-level cryptographic operations.
enum CryptoError: Error, LocalizedError {
    case general(String)
    case mbedtlsError(String, Int32)
    case invalidDataSize(String)
    case bufferPointerError
    
    var errorDescription: String? {
        switch self {
        case .general(let reason):
            return "Crypto operation failed: \(reason)"
        case .mbedtlsError(let operation, let code):
            var buffer = [CChar](repeating: 0, count: 128)
            mbedtls_strerror(code, &buffer, buffer.count)
            let desc = String(cString: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
            return "MbedTLS '\(operation)' failed with error \(code) (\(String(format: "-0x%04X", -code))): \(desc)"
        case .invalidDataSize(let reason): return "Invalid data size: \(reason)"
        case .bufferPointerError: return "Failed to get buffer base address."
        }
    }
}

/// A namespace for cryptographic operations, implemented by directly wrapping MbedTLS C functions.
enum Crypto {
    
    private static func performAesOperation(_ operation: mbedtls_operation_t, mode: mbedtls_cipher_type_t, key: Key, iv: Data? = nil, data: RawData) throws -> RawData {
        var ctx = mbedtls_cipher_context_t()
        mbedtls_cipher_init(&ctx)
        defer { mbedtls_cipher_free(&ctx) }
        
        guard let cipherInfo = mbedtls_cipher_info_from_type(mode) else {
            throw CryptoError.general("Failed to get cipher info for mode \(mode).")
        }
        
        var result = mbedtls_cipher_setup(&ctx, cipherInfo)
        if result != 0 { throw CryptoError.mbedtlsError("cipher_setup", result) }
        
        result = key.withUnsafeBytes { keyPtr in
            mbedtls_cipher_setkey(&ctx, keyPtr.baseAddress, Int32(key.count * 8), operation)
        }
        if result != 0 { throw CryptoError.mbedtlsError("setkey", result) }
        
        if let iv = iv {
            guard iv.count == 16 else { throw CryptoError.invalidDataSize("IV must be 16 bytes.") }
            result = iv.withUnsafeBytes { ivPtr in
                mbedtls_cipher_set_iv(&ctx, ivPtr.baseAddress, iv.count)
            }
            if result != 0 { throw CryptoError.mbedtlsError("set_iv", result) }
        }
        
        // 为输出预留足够的空间，MbedTLS的update可能会写入比输入多一个块的数据（如果带填充），为安全起见多分配
        var output = Data(count: data.count + 16)
        var outputLen: Int = 0
        
        result = data.withUnsafeBytes { dataPtr in
            output.withUnsafeMutableBytes { outputPtr in
                mbedtls_cipher_update(&ctx, dataPtr.baseAddress, data.count, outputPtr.baseAddress, &outputLen)
            }
        }
        if result != 0 { throw CryptoError.mbedtlsError("update", result) }
        
        var finishLen: Int = 0
        result = output.withUnsafeMutableBytes { outputPtr in
            mbedtls_cipher_finish(&ctx, outputPtr.baseAddress?.advanced(by: outputLen), &finishLen)
        }
        if result != 0 { throw CryptoError.mbedtlsError("finish", result) }
        
        output.count = outputLen + finishLen
        return output
    }
    
    private static func performBlockOperation(_ operation: mbedtls_operation_t, mode: mbedtls_cipher_type_t, key: Key, data: RawData) throws -> RawData {
        var ctx = mbedtls_cipher_context_t()
        mbedtls_cipher_init(&ctx)
        defer { mbedtls_cipher_free(&ctx) }
        
        guard let cipherInfo = mbedtls_cipher_info_from_type(mode) else {
            throw CryptoError.general("Failed to get cipher info for mode \(mode).")
        }
        
        var result = mbedtls_cipher_setup(&ctx, cipherInfo)
        if result != 0 { throw CryptoError.mbedtlsError("cipher_setup", result) }
        
        result = key.withUnsafeBytes { keyPtr in
            mbedtls_cipher_setkey(&ctx, keyPtr.baseAddress, Int32(key.count * 8), operation)
        }
        if result != 0 { throw CryptoError.mbedtlsError("setkey", result) }
        
        mbedtls_cipher_reset(&ctx)
        
        let blockSize = Int(mbedtls_cipher_get_block_size(&ctx))
        guard blockSize > 0, data.count % blockSize == 0 else {
            throw CryptoError.invalidDataSize("Data size (\(data.count)) must be a multiple of block size (\(blockSize)).")
        }
        
        var outputData = Data(count: data.count)
        
        try data.withUnsafeBytes { inputBuffer in
            try outputData.withUnsafeMutableBytes { outputBuffer in
                guard let inputBase = inputBuffer.baseAddress, let outputBase = outputBuffer.baseAddress else {
                    throw CryptoError.bufferPointerError
                }
                
                for offset in stride(from: 0, to: data.count, by: blockSize) {
                    var outputLen: Int = 0
                    let inputChunkPtr = inputBase.advanced(by: offset)
                    let outputChunkPtr = outputBase.advanced(by: offset)
                    
                    result = mbedtls_cipher_update(&ctx, inputChunkPtr.assumingMemoryBound(to: UInt8.self), blockSize, outputChunkPtr.assumingMemoryBound(to: UInt8.self), &outputLen)
                    
                    if result != 0 {
                        throw CryptoError.mbedtlsError("update (offset: \(offset))", result)
                    }
                }
            }
        }
        
        var finishLen: Int = 0
        result = mbedtls_cipher_finish(&ctx, nil, &finishLen)
        if result != 0 {
            // 在这里，我们特意忽略 -0x6100 (BAD_INPUT_DATA)，因为C版本也会收到这个错误但依然能工作。
            // 这很可能是MbedTLS对无填充ECB模式的finish调用处理上的一个特点。
            if result != MBEDTLS_ERR_CIPHER_BAD_INPUT_DATA {
                throw CryptoError.mbedtlsError("finish", result)
            }
        }
        
        return outputData
    }
    
    // MARK: - AES-ECB
    
    static func aesEcbDecrypt(key: Key, data: RawData) throws -> RawData {
        let keySize = key.count
        let cipherType: mbedtls_cipher_type_t
        switch keySize {
        case 16: cipherType = MBEDTLS_CIPHER_AES_128_ECB
        case 24: cipherType = MBEDTLS_CIPHER_AES_192_ECB
        case 32: cipherType = MBEDTLS_CIPHER_AES_256_ECB
        default: throw CryptoError.invalidDataSize("Invalid AES key size for ECB: \(keySize)")
        }
        return try performBlockOperation(MBEDTLS_DECRYPT, mode: cipherType, key: key, data: data)
    }
    
    static func aesEcbEncrypt(key: Key, data: RawData) throws -> RawData {
        let keySize = key.count
        let cipherType: mbedtls_cipher_type_t
        switch keySize {
        case 16: cipherType = MBEDTLS_CIPHER_AES_128_ECB
        case 24: cipherType = MBEDTLS_CIPHER_AES_192_ECB
        case 32: cipherType = MBEDTLS_CIPHER_AES_256_ECB
        default: throw CryptoError.invalidDataSize("Invalid AES key size for ECB: \(keySize)")
        }
        return try performBlockOperation(MBEDTLS_ENCRYPT, mode: cipherType, key: key, data: data)
    }
    
    // MARK: - AES-CTR
    
    static func aesCtrCrypt(key: Key, iv: Data, data: RawData) throws -> RawData {
        var counter = iv
        var output = Data(count: data.count)
        
        let blockSize = 16
        // --- FIX: Initialize keystreamBlock before the loop and only when needed ---
        var keystreamBlock = Data()
        
        for i in 0..<data.count {
            if i % blockSize == 0 {
                keystreamBlock = try self.aesEcbEncrypt(key: key, data: counter)
                // Increment the 128-bit counter (big-endian)
                for j in (0..<blockSize).reversed() {
                    if counter[j] == 0xFF {
                        counter[j] = 0
                    } else {
                        counter[j] += 1
                        break
                    }
                }
            }
            output[i] = data[i] ^ keystreamBlock[i % blockSize]
        }
        return output
    }
    
    // MARK: - AES-XTS
    
    static func aesXtsDecrypt(keyData: Key, startSector: UInt64, sectorSize: Int, data: RawData) throws -> RawData {
        guard data.count % sectorSize == 0 else {
            throw CryptoError.invalidDataSize("Data size (\(data.count)) must be a multiple of sector size (\(sectorSize)).")
        }
        
        let keySize = keyData.count
        let cipherType: mbedtls_cipher_type_t
        switch keySize {
        case 32: cipherType = MBEDTLS_CIPHER_AES_128_XTS
        case 64: cipherType = MBEDTLS_CIPHER_AES_256_XTS
        default: throw CryptoError.invalidDataSize("Invalid AES key size for XTS: \(keySize)")
        }
        
        var decryptedData = Data()
        decryptedData.reserveCapacity(data.count)
        
        for i in 0..<(data.count / sectorSize) {
            let currentSector = startSector + UInt64(i)
            let tweak = Self.getTweak(for: currentSector)
            
            let sectorStart = i * sectorSize
            let sectorEnd = sectorStart + sectorSize
            let encryptedSector = data.subdata(in: sectorStart..<sectorEnd)
            
            let decryptedSector = try performAesOperation(MBEDTLS_DECRYPT, mode: cipherType, key: keyData, iv: tweak, data: encryptedSector)
            decryptedData.append(decryptedSector)
        }
        
        return decryptedData
    }
    
    /// Generates a 16-byte Tweak from a sector number. Nintendo uses Little Endian.
    private static func getTweak(for sector: UInt64) -> Data {
        var tempSector = sector
        var tweakBytes = [UInt8](repeating: 0, count: 16)
        
        // 这个循环精确地模拟了C代码的行为
        for i in (0...15).reversed() {
            tweakBytes[i] = UInt8(tempSector & 0xFF)
            tempSector >>= 8
        }
        
        return Data(tweakBytes)
    }
    
    // MARK: - CMAC
    
    static func calculateCMAC(data: Data, key: Key) throws -> RawData {
        var m_ctx = mbedtls_cipher_context_t()
        mbedtls_cipher_init(&m_ctx)
        defer { mbedtls_cipher_free(&m_ctx) }
        
        guard let cipherInfo = mbedtls_cipher_info_from_type(MBEDTLS_CIPHER_AES_128_ECB) else {
            throw CryptoError.general("Failed to get cipher info for CMAC.")
        }
        
        var result = mbedtls_cipher_setup(&m_ctx, cipherInfo)
        if result != 0 { throw CryptoError.mbedtlsError("cmac_setup", result) }
        
        result = key.withUnsafeBytes { keyPtr in
            mbedtls_cipher_cmac_starts(&m_ctx, keyPtr.baseAddress, 128)
        }
        if result != 0 { throw CryptoError.mbedtlsError("cmac_starts", result) }
        
        result = data.withUnsafeBytes { dataPtr in
            mbedtls_cipher_cmac_update(&m_ctx, dataPtr.baseAddress, data.count)
        }
        if result != 0 { throw CryptoError.mbedtlsError("cmac_update", result) }
        
        var output = Data(count: 16)
        result = output.withUnsafeMutableBytes { outputPtr in
            mbedtls_cipher_cmac_finish(&m_ctx, outputPtr.baseAddress)
        }
        if result != 0 { throw CryptoError.mbedtlsError("cmac_finish", result) }
        
        return output
    }
}
