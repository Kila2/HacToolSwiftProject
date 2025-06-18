import Foundation
import CryptoSwift

typealias Key = Data
typealias RawData = Data

/// Custom errors for cryptographic operations.
enum CryptoError: Error, LocalizedError {
    case invalidKeySize
    case invalidDataSize
    case encryptionFailed(reason: String)
    case decryptionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidKeySize: return "Invalid key size for the cryptographic operation."
        case .invalidDataSize: return "Invalid data size for the cryptographic operation."
        case .encryptionFailed(let reason): return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason): return "Decryption failed: \(reason)"
        }
    }
}

/// Cryptographic operations implemented using CryptoSwift for cross-platform support.
enum Crypto {
    
    private static let AES_BLOCK_SIZE = 16

    // MARK: - AES-ECB
    
    static func aesEcbDecrypt(key: Key, data: RawData) throws -> RawData {
        guard data.count % AES_BLOCK_SIZE == 0 else { throw CryptoError.invalidDataSize }
        do {
            let aes = try AES(key: key.bytes, blockMode: ECB(), padding: .noPadding)
            let decryptedBytes = try aes.decrypt(data.bytes)
            return Data(decryptedBytes)
        } catch {
            throw CryptoError.decryptionFailed(reason: "CryptoSwift AES-ECB decryption failed. \(error)")
        }
    }

    static func aesEcbEncrypt(key: Key, data: RawData) throws -> RawData {
        guard data.count % AES_BLOCK_SIZE == 0 else { throw CryptoError.invalidDataSize }
        do {
            let aes = try AES(key: key.bytes, blockMode: ECB(), padding: .noPadding)
            let encryptedBytes = try aes.encrypt(data.bytes)
            return Data(encryptedBytes)
        } catch {
            throw CryptoError.encryptionFailed(reason: "CryptoSwift AES-ECB encryption failed. \(error)")
        }
    }

    // MARK: - AES-CTR

    static func aesCtrCrypt(key: Key, iv: Data, data: RawData) throws -> RawData {
        var counter = iv
        var output = Data(count: data.count)
        var keystream = Data()

        for i in 0..<data.count {
            if i % AES_BLOCK_SIZE == 0 {
                keystream = try aesEcbEncrypt(key: key, data: counter)
                for j in (0..<16).reversed() {
                    if counter[j] == 0xFF {
                        counter[j] = 0
                    } else {
                        counter[j] += 1
                        break
                    }
                }
            }
            output[i] = data[i] ^ keystream[i % AES_BLOCK_SIZE]
        }
        return output
    }

    // MARK: - AES-XTS
    
    static func aesXtsDecrypt(keyData: Key, tweakData: Data, data: RawData, sectorSize: Int) throws -> RawData {
        guard keyData.count == 32 else { throw CryptoError.invalidKeySize }
        guard data.count % sectorSize == 0 else { throw CryptoError.invalidDataSize }
        
        let key1Data = keyData.subdata(in: 0..<16)
        let key2Data = keyData.subdata(in: 16..<32)

        var decryptedData = Data()
        decryptedData.reserveCapacity(data.count)
        
        let encryptedInitialTweak = try aesEcbEncrypt(key: key2Data, data: tweakData)

        for i in 0..<(data.count / sectorSize) {
            var T = encryptedInitialTweak
            if i > 0 {
                T = GF128.xts_gf_mult(encryptedInitialTweak, by: i)
            }
            
            let sectorStart = i * sectorSize
            let sectorCiphertext = data.subdata(in: sectorStart..<(sectorStart + sectorSize))
            
            for j in 0..<(sectorSize / AES_BLOCK_SIZE) {
                let blockStart = j * AES_BLOCK_SIZE
                var blockCiphertext = sectorCiphertext.subdata(in: blockStart..<(blockStart + AES_BLOCK_SIZE))

                for k in 0..<AES_BLOCK_SIZE {
                    blockCiphertext[k] ^= T[k]
                }
                
                let intermediatePlaintext = try aesEcbDecrypt(key: key1Data, data: blockCiphertext)
                
                var blockPlaintext = Data(count: AES_BLOCK_SIZE)
                for k in 0..<AES_BLOCK_SIZE {
                    blockPlaintext[k] = intermediatePlaintext[k] ^ T[k]
                }
                
                decryptedData.append(blockPlaintext)
                
                T = GF128.xts_gf_mult_alpha(T)
            }
        }
        
        return decryptedData
    }
}

// FIXED: Changed from `private` to `internal` (default) so tests can access it.
enum GF128 {
    static func xts_gf_mult(_ x: Data, by power: Int) -> Data {
        if power == 0 { return x }
        var result = x
        for _ in 1...power {
            result = xts_gf_mult_alpha(result)
        }
        return result
    }

    static func xts_gf_mult_alpha(_ x: Data) -> Data {
        var result = Data(repeating: 0, count: 16)
        let feedback: UInt8 = (x[0] & 0x80) != 0 ? 0x87 : 0x00

        for i in (0..<15).reversed() {
            result[i+1] = (x[i+1] << 1) | (x[i] >> 7)
        }
        result[0] = (x[0] << 1) ^ feedback
        
        return result
    }
}