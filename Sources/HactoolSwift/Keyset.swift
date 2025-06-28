// Sources/HactoolSwift/Keyset.swift (添加了完整日志追踪的版本)
import Foundation

enum KeySetError: Error, CustomStringConvertible {
    case homeKeyNotExist
    var description: String {
        switch self {
            case .homeKeyNotExist: "~/.switch/prod.keys doesn't exist"
        }
    }
}

class Keyset {
    var masterKeys: [Data] = Array(repeating: Data(count: 16), count: 32)
    var headerKekSource = Data(count: 16)  // 确保这个属性存在
    var headerKeySource = Data(count: 32)
    var keyAreaKeyApplicationSource = Data(count: 16)
    var keyAreaKeyOceanSource = Data(count: 16)
    var keyAreaKeySystemSource = Data(count: 16)
    var aesKekGenerationSource = Data(count: 16)
    var aesKeyGenerationSource = Data(count: 16)
    
    var headerKey = Data(count: 32)
    var keyAreaKeys: [[Data]] = Array(repeating: Array(repeating: Data(count: 16), count: 3), count: 32)
    
    func load() throws {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        let keysURL = URL(fileURLWithPath: "\(homeURL.path)/.switch/prod.keys")
        guard FileManager.default.fileExists(atPath: keysURL.path) else {
            throw KeySetError.homeKeyNotExist
        }
        try load(from: keysURL)
    }
    
    func load(from fileURL: URL) throws {
        // --- DEBUG LOG ---
        print("[Swift DEBUG] ==> Keyset.load(from: \(fileURL.path))")
        let lines = try String(contentsOf: fileURL, encoding: .utf8).components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let name = parts[0]
                let hexValue = parts[1]
                guard let keyData = Data(fromHex: hexValue) else { continue }
                
                if name.starts(with: "master_key_") {
                    if let index = Int(name.dropFirst("master_key_".count), radix: 16), index < masterKeys.count {
                        masterKeys[index] = keyData
                        // --- DEBUG LOG ---
                        print("[Swift DEBUG]     Loaded master_key_\(String(format: "%02x", index)): \(keyData.hexEncodedString())")
                    }
                } else if name == "header_key" { // 确保支持直接加载 header_key
                    headerKey = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded header_key: \(keyData.hexEncodedString())")
                } else if name == "header_kek_source" {
                    headerKekSource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded header_kek_source: \(keyData.hexEncodedString())")
                } else if name == "header_key_source" {
                    headerKeySource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded header_key_source: \(keyData.hexEncodedString())")
                } else if name == "key_area_key_application_source" {
                    keyAreaKeyApplicationSource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded key_area_key_application_source: \(keyData.hexEncodedString())")
                } else if name == "key_area_key_ocean_source" {
                    keyAreaKeyOceanSource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded key_area_key_ocean_source: \(keyData.hexEncodedString())")
                } else if name == "key_area_key_system_source" {
                    keyAreaKeySystemSource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded key_area_key_system_source: \(keyData.hexEncodedString())")
                } else if name == "aes_kek_generation_source" {
                    aesKekGenerationSource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded aes_kek_generation_source: \(keyData.hexEncodedString())")
                } else if name == "aes_key_generation_source" {
                    aesKeyGenerationSource = keyData
                    // --- DEBUG LOG ---
                    print("[Swift DEBUG]     Loaded aes_key_generation_source: \(keyData.hexEncodedString())")
                }
            }
        }
        // --- DEBUG LOG ---
        print("[Swift DEBUG] <== Keyset.load finished.")
    }
    
    func deriveKeys() throws {
        print("Deriving keys...")
        
        // --- DEBUG LOG ---
        print("[Swift DEBUG] ==> Keyset.deriveKeys() starting...")
        
        if !headerKeySource.allSatisfy({ $0 == 0 }) && !headerKekSource.allSatisfy({ $0 == 0 }) {
            // --- DEBUG LOG ---
            print("[Swift DEBUG] --- Deriving Header KEK ---")
            print("[Swift DEBUG]     masterKey[0]: \(masterKeys[0].hexEncodedString())")
            print("[Swift DEBUG]     kekSeed:      \(aesKekGenerationSource.hexEncodedString())")
            print("[Swift DEBUG]     src:          \(headerKekSource.hexEncodedString())")
            print("[Swift DEBUG]     keySeed:      \(aesKeyGenerationSource.hexEncodedString())")
            
            let headerKek = try generateKek(
                src: self.headerKekSource,
                masterKey: masterKeys[0],
                kekSeed: aesKekGenerationSource,
                keySeed: aesKeyGenerationSource
            )
            
            // --- DEBUG LOG ---
            print("[Swift DEBUG] --- Decrypting Header Key ---")
            print("[Swift DEBUG]     headerKek:      \(headerKek.hexEncodedString())")
            print("[Swift DEBUG]     headerKeySource: \(headerKeySource.hexEncodedString())")
            
            self.headerKey = try Crypto.aesEcbDecrypt(key: headerKek, data: headerKeySource)
            print("  - Header Key derived: \(self.headerKey.hexEncodedString())")
        }
        
        for i in 0..<masterKeys.count {
            let masterKey = masterKeys[i]
            if masterKey.allSatisfy({ $0 == 0 }) { continue }
            
            // --- DEBUG LOG ---
            print("[Swift DEBUG] --- Deriving KeyAreaKey for revision \(i) ---")
            print("[Swift DEBUG]     masterKey[\(i)]: \(masterKey.hexEncodedString())")
            print("[Swift DEBUG]     kekSeed:      \(aesKekGenerationSource.hexEncodedString())")
            print("[Swift DEBUG]     keySeed:      \(aesKeyGenerationSource.hexEncodedString())")
            
            print("[Swift DEBUG]   - Application key...")
            print("[Swift DEBUG]     src:          \(keyAreaKeyApplicationSource.hexEncodedString())")
            keyAreaKeys[i][0] = try generateKek(src: keyAreaKeyApplicationSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
            
            print("[Swift DEBUG]   - Ocean key...")
            print("[Swift DEBUG]     src:          \(keyAreaKeyOceanSource.hexEncodedString())")
            keyAreaKeys[i][1] = try generateKek(src: keyAreaKeyOceanSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
            
            print("[Swift DEBUG]   - System key...")
            print("[Swift DEBUG]     src:          \(keyAreaKeySystemSource.hexEncodedString())")
            keyAreaKeys[i][2] = try generateKek(src: keyAreaKeySystemSource, masterKey: masterKey, kekSeed: aesKeyGenerationSource, keySeed: aesKeyGenerationSource)
        }
        print("  - Key Area Keys derived for all revisions.")
        
        // --- DEBUG LOG ---
        print("[Swift DEBUG] <== Keyset.deriveKeys() finished.")
        print("Key derivation complete.")
    }
    
    // 使用我们之前确认过的、与 C 语言逻辑一致的实现
    private func generateKek(src: Data, masterKey: Data, kekSeed: Data, keySeed: Data) throws -> Data {
        // --- DEBUG LOG ---
        print("[Swift DEBUG]   ==> generateKek called.")
        
        // 第一次解密：kek = Decrypt(master_key, kek_seed)
        let kek = try Crypto.aesEcbDecrypt(key: masterKey, data: kekSeed)
        // --- DEBUG LOG ---
        print("[Swift DEBUG]     step 1 (kek): \(kek.hexEncodedString())")
        
        // 第二次解密：src_kek = Decrypt(kek, src)
        let srcKek = try Crypto.aesEcbDecrypt(key: kek, data: src)
        // --- DEBUG LOG ---
        print("[Swift DEBUG]     step 2 (srcKek): \(srcKek.hexEncodedString())")
        
        // 第三次解密：result = Decrypt(src_kek, key_seed)
        let finalKey = try Crypto.aesEcbDecrypt(key: srcKek, data: keySeed)
        // --- DEBUG LOG ---
        print("[Swift DEBUG]     step 3 (final): \(finalKey.hexEncodedString())")
        print("[Swift DEBUG]   <== generateKek finished.")
        
        return finalKey
    }
}
