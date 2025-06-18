import Foundation

class Keyset {
    var masterKeys: [Data] = Array(repeating: Data(count: 16), count: 32)
    var headerKeySource = Data(count: 32)
    var keyAreaKeyApplicationSource = Data(count: 16)
    var keyAreaKeyOceanSource = Data(count: 16)
    var keyAreaKeySystemSource = Data(count: 16)
    var aesKekGenerationSource = Data(count: 16)
    var aesKeyGenerationSource = Data(count: 16)

    var headerKey = Data(count: 32)
    var keyAreaKeys: [[Data]] = Array(repeating: Array(repeating: Data(count: 16), count: 3), count: 32)
    
    func load(from fileURL: URL) throws {
        let lines = try String(contentsOf: fileURL, encoding: .utf8).components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                guard let keyData = Data(fromHex: parts[1]) else { continue }
                let name = parts[0]
                
                if name.starts(with: "master_key_") {
                    if let index = Int(name.dropFirst("master_key_".count), radix: 16), index < masterKeys.count {
                        masterKeys[index] = keyData
                    }
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
        
        if !headerKeySource.allSatisfy({ $0 == 0 }) {
            let headerKek = try generateKek(
                src: headerKeySource.subdata(in: 0..<16),
                masterKey: masterKeys[0], 
                kekSeed: aesKekGenerationSource,
                keySeed: aesKeyGenerationSource
            )
            self.headerKey = try Crypto.aesEcbDecrypt(key: headerKek, data: headerKeySource)
            print("  - Header Key derived.")
        }
        
        for i in 0..<masterKeys.count {
            let masterKey = masterKeys[i]
            if masterKey.allSatisfy({ $0 == 0 }) { continue }
            
            keyAreaKeys[i][0] = try generateKek(src: keyAreaKeyApplicationSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
            keyAreaKeys[i][1] = try generateKek(src: keyAreaKeyOceanSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
            keyAreaKeys[i][2] = try generateKek(src: keyAreaKeySystemSource, masterKey: masterKey, kekSeed: aesKekGenerationSource, keySeed: aesKeyGenerationSource)
        }
        print("  - Key Area Keys derived for all revisions.")
        print("Key derivation complete.")
    }

    private func generateKek(src: Data, masterKey: Data, kekSeed: Data, keySeed: Data) throws -> Data {
        let kek = try Crypto.aesEcbDecrypt(key: masterKey, data: kekSeed)
        let srcKek = try Crypto.aesEcbDecrypt(key: kek, data: src)
        return try Crypto.aesEcbDecrypt(key: srcKek, data: keySeed)
    }
}
