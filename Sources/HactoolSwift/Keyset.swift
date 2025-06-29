// Sources/HactoolSwift/Keyset.swift
import Foundation

enum KeySetError: Error, CustomStringConvertible {
    case homeKeyNotExist
    var description: String {
        switch self {
            case .homeKeyNotExist: "Could not find keyset file. Common paths are ~/.switch/prod.keys or a file specified with --keyset."
        }
    }
}

class Keyset {
    var masterKeys: [Data] = Array(repeating: Data(count: 16), count: 32)
    var headerKekSource = Data(count: 16)
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
                    }
                } else if name == "header_key" {
                    headerKey = keyData
                } else if name == "header_kek_source" {
                    headerKekSource = keyData
                } else if name == "header_key_source" {
                    headerKeySource = keyData
                } else if name == "key_area_key_application_source" {
                    keyAreaKeyApplicationSource = keyData
                } else if name == "key_area_key_ocean_source" {
                    keyAreaKeyOceanSource = keyData
                } else if name == "key_area_key_system_source" {
                    keyAreaKeySystemSource = keyData
                } else if name == "aes_kek_generation_source" {
                    aesKekGenerationSource = keyData
                } else if name == "aes_key_generation_source" {
                    aesKeyGenerationSource = keyData
                }
            }
        }
    }
    
    func deriveKeys() throws {
        print("Deriving keys...")
        
        // Derive header key if sources are available
        if !headerKeySource.allSatisfy({ $0 == 0 }) && !headerKekSource.allSatisfy({ $0 == 0 }) {
            let headerKek = try generateKek(
                src: self.headerKekSource,
                masterKey: masterKeys[0],
                kekSeed: aesKekGenerationSource,
                keySeed: aesKeyGenerationSource
            )
            
            self.headerKey = try Crypto.aesEcbDecrypt(key: headerKek, data: headerKeySource)
            print("  - Header Key derived: \(self.headerKey.hexEncodedString())")
        }
        
        // Derive key area keys for each master key revision
        for i in 0..<masterKeys.count {
            let masterKey = masterKeys[i]
            if masterKey.allSatisfy({ $0 == 0 }) { continue }
            
            keyAreaKeys[i][0] = try generateKek(src: keyAreaKeyApplicationSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
            keyAreaKeys[i][1] = try generateKek(src: keyAreaKeyOceanSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
            keyAreaKeys[i][2] = try generateKek(src: keyAreaKeySystemSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
        }
        
        print("  - Key Area Keys derived for all active revisions.")
        print("Key derivation complete.")
    }
    
    /// Generates a key using a three-step AES-ECB decryption process, common in Switch key derivation.
    private func generateKek(src: Data, masterKey: Data, kekSeed: Data, keySeed: Data) throws -> Data {
        // Step 1: Decrypt the KEK seed with the master key
        let kek = try Crypto.aesEcbDecrypt(key: masterKey, data: kekSeed)
        
        // Step 2: Decrypt the source key with the result from step 1
        let srcKek = try Crypto.aesEcbDecrypt(key: kek, data: src)
        
        // Step 3: Decrypt the final key seed with the result from step 2
        let finalKey = try Crypto.aesEcbDecrypt(key: srcKek, data: keySeed)
        
        return finalKey
    }
}
