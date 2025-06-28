import Foundation

// MARK: - Enums and Structs
enum NCAVersion: CustomStringConvertible {
    case nca3, nca2, nca0, unknown
    var description: String {
        switch self {
        case .nca3: "NCA3"
        case .nca2: "NCA2"
        case .nca0: "NCA0"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - NCAParser Class (Fully Repaired)
class NCAParser: PrettyPrintable, JSONSerializable {
    let dataProvider: DataProvider
    let keyset: Keyset
    var header: NCAHeader!
    var version: NCAVersion = .unknown
    private var decryptedHeaderData: Data!
    private var decryptedSectionKeys: [Data] = []
    private var sectionContent: [Int: (PrettyPrintable & JSONSerializable)] = [:]
    
    init(dataProvider: @escaping DataProvider, keyset: Keyset) {
        self.dataProvider = dataProvider
        self.keyset = keyset
    }

    func parse() throws {
        try parseAndDecryptHeader()
        try decryptKeyArea()
    }

    private func parseAndDecryptHeader() throws {
        print("\n--- Swift NCA Header Decryption Debug ---")
        let rawHeaderData = try dataProvider(0, 0xC00)
        print("1. Raw Header Data (first 16 bytes): \(rawHeaderData.subdata(in: 0..<16).hexEncodedString())")
        
        var xtsKey = keyset.headerKey
        if xtsKey.count == 16 { xtsKey.append(xtsKey) }
        print("2. Header Key (XTS, 32 bytes): \(xtsKey.hexEncodedString())")
        guard xtsKey.count == 32 else { throw CryptoError.general("Invalid XTS key size") }

        let decryptedFirstPass = try Crypto.aesXtsDecrypt(keyData: xtsKey, startSector: 0, sectorSize: 0x200, data: rawHeaderData.subdata(in: 0..<0x400))
        
        try decryptedFirstPass.withUnsafeBytes { (buffer: UnsafeRawBufferPointer)  in
            let magicString = try readMagic(from: buffer, at: 0x200)
            
            switch magicString {
            case "NCA3":
                self.version = .nca3
                print("   -> Detected NCA3 format.")
                self.decryptedHeaderData = try Crypto.aesXtsDecrypt(keyData: xtsKey, startSector: 0, sectorSize: 0x200, data: rawHeaderData)

            case "NCA2":
                self.version = .nca2
                print("   -> Detected NCA2 format.")
                var tempFullHeader = Data(decryptedFirstPass)
                for i in 0..<4 {
                    let fsHeaderOffset = 0x400 + (i * 0x200)
                    let encryptedFsHeader = rawHeaderData.subdata(in: fsHeaderOffset..<(fsHeaderOffset + 0x200))
                    let decryptedFsHeader = try Crypto.aesXtsDecrypt(keyData: xtsKey, startSector: 0, sectorSize: 0x200, data: encryptedFsHeader)
                    tempFullHeader.append(decryptedFsHeader)
                }
                self.decryptedHeaderData = tempFullHeader

            case "NCA0":
                self.version = .nca0
                throw ParserError.unknownFormat("NCA0 format is not supported yet.")

            default:
                self.version = .unknown
                throw ParserError.invalidMagic(expected: "NCA3/NCA2", found: magicString ?? "Unreadable")
            }
        }

        try parseDecryptedHeader(from: self.decryptedHeaderData)
    }
    
    internal func parseDecryptedHeader(from d: Data) throws {
        try d.withUnsafeBytes { buffer in
            self.header = try NCAHeader.parse(from: buffer)
        }
    }

    private func decryptKeyArea() throws {
        guard let decryptedHeaderData = self.decryptedHeaderData, let header = self.header else {
            throw ParserError.general("Header not parsed before decrypting key area.")
        }
        
        try decryptedHeaderData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            let kaekIndex: UInt8 = try readLE(from: buffer, at: 0x207)
            let keyAreaKey = keyset.keyAreaKeys[Int(header.cryptoType.rawValue)][Int(kaekIndex)]
            let encryptedKeys = decryptedHeaderData.subdata(in: 0x300..<0x340)
            
            for i in 0..<4 {
                let encryptedKey = encryptedKeys.subdata(in: (i*16)..<(i*16 + 16))
                decryptedSectionKeys.append(try Crypto.aesEcbDecrypt(key: keyAreaKey, data: encryptedKey))
            }
        }
    }

    func readDecryptedData(sectionIndex: Int, offset: UInt64, size: Int) throws -> Data {
        guard sectionIndex < 4, let header = header else { throw ParserError.dataOutOfBounds(reason: "Invalid section index.") }
        let section = header.sectionEntries[sectionIndex]
        guard section.size > 0, offset + UInt64(size) <= section.size else {
            throw ParserError.dataOutOfBounds(reason: "Read for section \(sectionIndex) is out of bounds.")
        }
        
        let key1 = decryptedSectionKeys[sectionIndex]
        
        switch header.cryptoType {
        case .none:
            return try dataProvider(UInt64(section.mediaOffset) + offset, size)
            
        case .ctr:
            let readStart = offset
            let readEnd = offset + UInt64(size)
            let alignedStart = (readStart / 16) * 16
            let alignedEnd = (readEnd + 15) / 16 * 16
            guard alignedEnd > alignedStart else { return Data() }
            let alignedReadSize = Int(alignedEnd - alignedStart)
            let fileOffsetForAlignedRead = UInt64(section.mediaOffset) + alignedStart
            let encryptedAlignedData = try dataProvider(fileOffsetForAlignedRead, alignedReadSize)
            
            var iv = Data(repeating: 0, count: 16)
            self.decryptedHeaderData.withUnsafeBytes { buffer in
                 let sectionCtrOffset = 0x400 + (sectionIndex * 0x200) + 0x140
                 let ctrData = Data(buffer[sectionCtrOffset..<(sectionCtrOffset + 8)])
                 iv.replaceSubrange(0..<8, with: ctrData)
            }
            
            var blockCounter = (alignedStart / 16).bigEndian
            withUnsafeBytes(of: &blockCounter) { iv.replaceSubrange(8..<16, with: $0) }
            
            let decryptedAlignedData = try Crypto.aesCtrCrypt(key: key1, iv: iv, data: encryptedAlignedData)
            
            let sliceStart = Int(readStart - alignedStart)
            let sliceEnd = sliceStart + size
            guard sliceEnd <= decryptedAlignedData.count else {
                throw ParserError.dataOutOfBounds(reason: "Internal error: Slice calculation failed for CTR.")
            }
            return decryptedAlignedData.subdata(in: sliceStart..<sliceEnd)

        case .xts:
             let key2 = decryptedSectionKeys[sectionIndex + 2]
             let sectionKey = key1 + key2
             let sectorSize = 0x200
             
             let readStart = offset
             let readEnd = offset + UInt64(size)
             let alignedStart = (readStart / UInt64(sectorSize)) * UInt64(sectorSize)
             let alignedEnd = ((readEnd + UInt64(sectorSize) - 1) / UInt64(sectorSize)) * UInt64(sectorSize)
             let alignedReadSize = Int(alignedEnd - alignedStart)
             
             let fileOffsetForAlignedRead = UInt64(section.mediaOffset) + alignedStart
             let encryptedAlignedData = try dataProvider(fileOffsetForAlignedRead, alignedReadSize)
             let startSector = alignedStart / UInt64(sectorSize)
             let decryptedAlignedData = try Crypto.aesXtsDecrypt(keyData: sectionKey, startSector: startSector, sectorSize: sectorSize, data: encryptedAlignedData)
             
             let sliceStart = Int(readStart - alignedStart)
             let sliceEnd = sliceStart + size
             guard sliceEnd <= decryptedAlignedData.count else {
                 throw ParserError.dataOutOfBounds(reason: "Internal error: Slice calculation failed for XTS.")
             }
             return decryptedAlignedData.subdata(in: sliceStart..<sliceEnd)

        case .bktr:
            print("Warning: Unsupported crypto type \(header.cryptoType).")
            return try dataProvider(UInt64(section.mediaOffset) + offset, size)
        }
    }
    
    func toPrettyString(indent: String) -> String {
        guard let header = header else { return "\(indent)NCA not parsed.\n" }
        var output = "\(indent)--- NCA Summary (\(version)) ---\n"
        output += String(format: "\(indent)Title ID: %016llX\n", header.titleId)
        output += "\(indent)Content Type: \(header.contentType)\n"
        output += "\(indent)Master Key Revision: \(header.cryptoType)\n"
        for (i, section) in header.sectionEntries.enumerated() where section.size > 0 {
            output += "\(indent)  Section \(i):\n"
            output += String(format: "\(indent)    Offset: 0x%llx, Size: 0x%llx\n", section.mediaOffset, section.size)
            let fsTypeString = String(describing: header.fsHeaders[i].fsType?.description)
            output += "\(indent)    FS Type: \(fsTypeString)\n"
            output += "\(indent)    Crypto: \(header.cryptoType)\n"
            if let content = sectionContent[i] {
                output += content.toPrettyString(indent: indent + "      ")
            }
        }
        output += "\(indent)--------------------\n"
        return output
    }
    
    func toJSONObject(includeData: Bool) -> Any {
        guard let header = header else { return [:] }
        let sections = header.sectionEntries.enumerated().compactMap { (i, s) -> [String: Any]? in
            guard s.size > 0 else { return nil }
            var sectionJSON: [String: Any] = [
                "section_index": i, "offset": String(format: "0x%llx", s.mediaOffset), "size": String(format: "0x%llx", s.size),
                "fs_type_raw": String(describing: header.fsHeaders[i].fsType?.description),
                "crypto_type": "\(header.cryptoType)"
            ]
            if let content = sectionContent[i] {
                sectionJSON["content"] = content.toJSONObject(includeData: includeData)
            }
            return sectionJSON
        }
        return [
            "nca_version": "\(version)",
            "title_id": String(format: "%016llX", header.titleId),
            "content_type": "\(header.contentType)",
            "master_key_revision": header.cryptoType,
            "sections": sections
        ]
    }

    func extractSection(_ sectionIndex: Int, to extractor: FileExtractor) throws {
        guard let content = sectionContent[sectionIndex] else {
            print("Section \(sectionIndex) was not parsed or is empty, cannot extract.")
            return
        }
        
        if let pfs0Partition = content as? PFS0Partition {
            try pfs0Partition.extractFiles(to: extractor)
        } else if let romfsParser = content as? RomFSParser {
            try romfsParser.extractFiles(to: extractor)
        } else {
             print("Section \(sectionIndex) has an unsupported filesystem type for extraction.")
        }
    }
}
