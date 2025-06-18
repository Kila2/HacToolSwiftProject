import Foundation

enum NCAContentType: UInt8, CustomStringConvertible, Codable {
    case program = 0, meta, control, manual, data, publicData
    
    var description: String {
        switch self {
            case .program: "Program"
            case .meta: "Meta"
            case .control: "Control"
            case .manual: "Manual"
            case .data: "Data"
            case .publicData: "PublicData"
        }
    }
}

enum NCAEncryptionType: UInt8, CustomStringConvertible, Codable {
    case none = 1, xts, ctr, bktr
    
    var description: String {
        switch self {
            case .none: "None"
            case .xts: "AES-XTS"
            case .ctr: "AES-CTR"
            case .bktr: "BKTR/Patch"
        }
    }
}

struct NCAHeader {
    let magic: String
    let contentType: NCAContentType
    let cryptoType: UInt8
    let titleId: UInt64
    var sectionEntries: [SectionEntry] = []
    
    struct SectionEntry {
        let offset: UInt64, size: UInt64
        let fsType: UInt8
        let cryptoType: NCAEncryptionType
    }
}

class NCAParser: PrettyPrintable, JSONSerializable {
    let dataProvider: DataProvider
    let keyset: Keyset
    var header: NCAHeader!
    private var decryptedSectionKeys: [Data] = []
    private var decryptedHeaderData: Data!
    private var sectionContent: [Int: (PrettyPrintable & JSONSerializable)] = [:]
    
    init(dataProvider: @escaping DataProvider, keyset: Keyset) {
        self.dataProvider = dataProvider
        self.keyset = keyset
    }

    func parse() throws {
        try parseAndDecryptHeader()
        try decryptKeyArea()
        try parseSections()
    }

     private func parseAndDecryptHeader() throws {
        // Read just the header from the file
        let rawHeaderData = try dataProvider(0, 0xC00)
        
        var xtsKey = keyset.headerKey
        if xtsKey.count == 16 { xtsKey.append(xtsKey) }
        guard xtsKey.count == 32 else { throw CryptoError.invalidKeySize }
        let tweak = Data(repeating: 0, count: 16)
        self.decryptedHeaderData = try Crypto.aesXtsDecrypt(keyData: xtsKey, tweakData: tweak, data: rawHeaderData, sectorSize: 0x200)
        
        let d = decryptedHeaderData!
        
        let magic: UInt32 = try readLE(from: d, at: 0x200)
        let magicBigEndian = magic.bigEndian
        let magicData = withUnsafeBytes(of: magicBigEndian) { Data($0) }

        guard let magicString = String(data: magicData, encoding: .ascii), magicString == "NCA3" else {
            throw ParserError.invalidMagic(expected: "NCA3", found: String(data: magicData, encoding: .ascii) ?? "Unreadable")
        }
        
        let contentTypeRaw: UInt8 = try readLE(from: d, at: 0x205)
        let cryptoTypeRaw: UInt8 = try readLE(from: d, at: 0x206)
        let titleId: UInt64 = try readLE(from: d, at: 0x210)

        guard let contentType = NCAContentType(rawValue: contentTypeRaw) else {
            throw ParserError.unknownFormat("Unknown NCA Content Type: \\(contentTypeRaw)")
        }

        var parsedHeader = NCAHeader(
            magic: "NCA3",
            contentType: contentType,
            cryptoType: cryptoTypeRaw > 0 ? cryptoTypeRaw - 1 : 0,
            titleId: titleId.bigEndian
        )

        var currentOffset = 0x220
        for i in 0..<4 {
            let mediaStartOffset: UInt32 = try readLE(from: d, at: currentOffset)
            let mediaEndOffset: UInt32 = try readLE(from: d, at: currentOffset + 4)
            currentOffset += 16
            
            if mediaStartOffset > 0 {
                let fsHeaderOffset = 0x400 + (i * 0x200)
                let fsType: UInt8 = try readLE(from: d, at: fsHeaderOffset + 0x3)
                let cryptoTypeRaw: UInt8 = try readLE(from: d, at: fsHeaderOffset + 0x4)
                guard let cryptoType = NCAEncryptionType(rawValue: cryptoTypeRaw) else {
                    throw ParserError.unknownFormat("Unknown NCA Crypto Type: \\(cryptoTypeRaw) for section \\(i)")
                }
                parsedHeader.sectionEntries.append(NCAHeader.SectionEntry(offset: UInt64(mediaStartOffset) * 0x200, size: UInt64(mediaEndOffset - mediaStartOffset) * 0x200, fsType: fsType, cryptoType: cryptoType))
            } else {
                parsedHeader.sectionEntries.append(NCAHeader.SectionEntry(offset: 0, size: 0, fsType: 0, cryptoType: .none))
            }
        }
        self.header = parsedHeader
    }

    private func decryptKeyArea() throws {
        let kaekIndex: UInt8 = try readLE(from: decryptedHeaderData, at: 0x207)
        let keyAreaKey = keyset.keyAreaKeys[Int(header.cryptoType)][Int(kaekIndex)]
        let encryptedKeys = decryptedHeaderData.subdata(in: 0x300..<0x340)
        for i in 0..<4 {
            let encryptedKey = encryptedKeys.subdata(in: (i*16)..<(i*16 + 16))
            decryptedSectionKeys.append(try Crypto.aesEcbDecrypt(key: keyAreaKey, data: encryptedKey))
        }
    }

    private func parseSections() throws {
        for i in 0..<4 {
            guard header.sectionEntries[i].size > 0 else { continue }
            let section = header.sectionEntries[i]

            // Create a specialized data provider for this section, which handles decryption on the fly.
            let sectionDataProvider: DataProvider = { (offset: UInt64, size: Int) throws -> Data in
                return try self.readDecryptedData(sectionIndex: i, offset: offset, size: size)
            }

            switch section.fsType {
            case 2: // PFS0
                let pfs0Partition = try PFS0Parser.parse(dataProvider: sectionDataProvider)
                sectionContent[i] = pfs0Partition
            case 3: // RomFS
                let romfsParser = RomFSParser(dataProvider: sectionDataProvider)
                try romfsParser.parse()
                sectionContent[i] = romfsParser
            default:
                print("Section \(i) has an unsupported filesystem type (\(section.fsType)) for parsing.")
            }
        }
    }

    func readDecryptedData(sectionIndex: Int, offset: UInt64, size: Int) throws -> Data {
        guard sectionIndex < 4, let header = header else { throw ParserError.dataOutOfBounds(reason: "Invalid section index.") }
        let section = header.sectionEntries[sectionIndex]
        guard section.size > 0, offset + UInt64(size) <= section.size else { throw ParserError.dataOutOfBounds(reason: "Read out of bounds for section \(sectionIndex).") }
        
        // Read encrypted data from the main file provider
        let fileOffset = section.offset + offset
        let encryptedData = try dataProvider(fileOffset, size)
        
        let key1 = decryptedSectionKeys[sectionIndex]
        
        switch section.cryptoType {
        case .ctr:
            var iv = Data(repeating: 0, count: 16)
            let sectionCtrOffset = 0x400 + (sectionIndex * 0x200) + 0x140
            let sectionCtr = decryptedHeaderData.subdata(in: sectionCtrOffset..<(sectionCtrOffset + 8))
            iv.replaceSubrange(0..<8, with: sectionCtr)
            var ctrValue = (offset / 16).bigEndian
            withUnsafeBytes(of: &ctrValue) { iv.replaceSubrange(8..<16, with: $0) }
            return try Crypto.aesCtrCrypt(key: key1, iv: iv, data: encryptedData)
            
        case .xts:
            let key2 = decryptedSectionKeys[sectionIndex + 2]
            let sectionKey = key1 + key2
            let sectorSize = 0x200
            let sectorNumber = offset / UInt64(sectorSize)
            var tweak = Data(repeating: 0, count: 16)
            var leSectorNumber = sectorNumber.littleEndian
            let tweakData = Data(bytes: &leSectorNumber, count: MemoryLayout.size(ofValue: leSectorNumber))
            tweak.replaceSubrange(0..<tweakData.count, with: tweakData)
            return try Crypto.aesXtsDecrypt(keyData: sectionKey, tweakData: tweak, data: encryptedData, sectorSize: sectorSize)
            
        case .none:
            return encryptedData
            
        default:
            print("Warning: Unsupported crypto type \(section.cryptoType) for section \(sectionIndex). Returning encrypted data.")
            return encryptedData
        }
    }

    func toPrettyString(indent: String) -> String {
        guard let header = header else { return "\(indent)NCA not parsed.\n" }
        var output = "\(indent)--- NCA Summary ---\n"
        output += String(format: "\(indent)Title ID: %016llX\n", header.titleId)
        output += "\(indent)Content Type: \(header.contentType)\n"
        output += "\(indent)Master Key Revision: \(header.cryptoType)\n"
        for (i, section) in header.sectionEntries.enumerated() where section.size > 0 {
            output += "\(indent)  Section \(i):\n"
            output += String(format: "\(indent)    Offset: 0x%llx, Size: 0x%llx\n", section.offset, section.size)
            let fsTypeString = section.fsType == 2 ? "PFS0" : (section.fsType == 3 ? "RomFS" : "Unknown (\(section.fsType))")
            output += "\(indent)    FS Type: \(fsTypeString)\n"
            output += "\(indent)    Crypto: \(section.cryptoType)\n"
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
                "section_index": i, "offset": String(format: "0x%llx", s.offset), "size": String(format: "0x%llx", s.size),
                "fs_type_raw": s.fsType, "fs_type": s.fsType == 2 ? "PFS0" : (s.fsType == 3 ? "RomFS" : "Unknown"), 
                "crypto_type": "\(s.cryptoType)"
            ]
            if let content = sectionContent[i] {
                sectionJSON["content"] = content.toJSONObject(includeData: includeData)
            }
            return sectionJSON
        }
        return [ "title_id": String(format: "%016llX", header.titleId), "content_type": "\(header.contentType)", "master_key_revision": header.cryptoType, "sections": sections ]
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