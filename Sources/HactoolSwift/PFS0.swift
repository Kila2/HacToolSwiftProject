import Foundation

// --- Data Models (Value Types) ---
struct PFS0Header {
    let magic: UInt32, fileCount: UInt32, stringTableSize: UInt32, reserved: UInt32
}

struct PFS0FileEntry {
    let offset: UInt64, size: UInt64, stringTableOffset: UInt32
    let hashedSize: UInt32, reserved: UInt64, hash: Data
    let name: String
    let dataProvider: DataProvider?
}

// Represents a fully parsed, immutable PFS0/HFS0 partition
struct PFS0Partition: PrettyPrintable, JSONSerializable {
    let header: PFS0Header
    let files: [PFS0FileEntry]
    
    func toPrettyString(indent: String) -> String {
        var output = ""
        let magicData = withUnsafeBytes(of: header.magic) { Data($0) }
        let magicString = String(data: magicData, encoding: .ascii) ?? "????"
        output += "\(indent)Magic:             \(magicString)\n"
        output += "\(indent)File Count:        \(header.fileCount)\n"
        
        if !files.isEmpty {
            output += "\(indent)Files:\n"
            for entry in files {
                let paddedName = entry.name.padding(toLength: 56, withPad: " ", startingAt: 0)
                let startOffset = entry.offset
                let endOffset = entry.offset + entry.size
                output += String(format: "\(indent)  %@ %012llx-%012llx\n", paddedName, startOffset, endOffset)
            }
        }
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        let filesJSON = files.map { entry -> [String: Any] in
            var fileJSON: [String: Any] = [
                "name": entry.name, "size": entry.size, "offset": String(format: "0x%llx", entry.offset)
            ]
            if includeData, let provider = entry.dataProvider {
                do {
                    let data = try provider(0, Int(entry.size))
                    fileJSON["data_base64"] = data.base64EncodedString()
                } catch {
                    fileJSON["data_base64"] = "Error reading data: \(error.localizedDescription)"
                }
            }
            return fileJSON
        }
        let magicData = withUnsafeBytes(of: header.magic) { Data($0) }
        let magicString = String(data: magicData, encoding: .ascii) ?? "????"
        return [ "type": magicString, "file_count": header.fileCount, "string_table_size": header.stringTableSize, "files": filesJSON ]
    }

    func extractFiles(to extractor: FileExtractor) throws {
        print("Extracting \(files.count) files from PFS0/HFS0...")
        for entry in files {
            guard let provider = entry.dataProvider else {
                print("  - Skipping \(entry.name): File data provider is not available.")
                continue
            }
            let fileData = try provider(0, Int(entry.size))
            try extractor.extract(path: entry.name, data: fileData)
        }
        print("Extraction complete.")
    }
}

// --- Parser (Stateless) ---
enum PFS0Parser {
    static func parse(dataProvider: @escaping DataProvider, baseOffset: UInt64 = 0, magic: String = "PFS0", loadFileData: Bool = true) throws -> PFS0Partition {
        let headerData = try dataProvider(baseOffset, 16)
        
        // FIXED: Explicitly type the buffer parameter
        return try headerData.withUnsafeBytes { (headerBuffer: UnsafeRawBufferPointer) -> PFS0Partition in
            let readMagic: UInt32 = try readLE(from: headerBuffer, at: 0)
            let magicData = withUnsafeBytes(of: readMagic) { Data($0) }
            guard let magicString = String(data: magicData, encoding: .ascii), magicString == magic else {
                throw ParserError.invalidMagic(expected: magic, found: String(data: magicData, encoding: .ascii) ?? "Unreadable")
            }
            
            let fileCount: UInt32 = try readLE(from: headerBuffer, at: 4)
            let stringTableSize: UInt32 = try readLE(from: headerBuffer, at: 8)
            let reserved: UInt32 = try readLE(from: headerBuffer, at: 12)
            let header = PFS0Header(magic: readMagic, fileCount: fileCount, stringTableSize: stringTableSize, reserved: reserved)

            let isHFS0 = (magic == "HFS0")
            let entrySize = isHFS0 ? 64 : 24
            
            let metadataSize = Int(fileCount) * entrySize + Int(stringTableSize)
            let metadata = try dataProvider(baseOffset + 16, metadataSize)

            // FIXED: Explicitly type the buffer parameter
            return try metadata.withUnsafeBytes { (metadataBuffer: UnsafeRawBufferPointer) -> PFS0Partition in
                let fileEntryTableSize = Int(fileCount) * entrySize
                let stringTableOffsetInMeta = fileEntryTableSize
                let fileDataBaseOffset = baseOffset + 16 + UInt64(metadataSize)

                var fileEntries: [PFS0FileEntry] = []

                for i in 0..<Int(fileCount) {
                    let currentEntryBaseOffset = i * entrySize
                    
                    let offset: UInt64 = try readLE(from: metadataBuffer, at: currentEntryBaseOffset + 0)
                    let size: UInt64 = try readLE(from: metadataBuffer, at: currentEntryBaseOffset + 8)
                    let stringTableRelOffset: UInt32 = try readLE(from: metadataBuffer, at: currentEntryBaseOffset + 16)
                    
                    var hashedSize: UInt32 = 0
                    var entryReserved: UInt64 = 0
                    var hash = Data()

                    if isHFS0 {
                        hashedSize = try readLE(from: metadataBuffer, at: currentEntryBaseOffset + 20)
                        entryReserved = try readLE(from: metadataBuffer, at: currentEntryBaseOffset + 24)
                        hash = metadata.subdata(in: (currentEntryBaseOffset + 32)..<(currentEntryBaseOffset + 64))
                    } else {
                        hashedSize = try readLE(from: metadataBuffer, at: currentEntryBaseOffset + 20)
                    }

                    let nameAbsoluteOffset = stringTableOffsetInMeta + Int(stringTableRelOffset)
                    var end = nameAbsoluteOffset
                    while end < metadata.count && metadata[end] != 0 { end += 1 }
                    
                    let nameData = metadata.subdata(in: nameAbsoluteOffset..<end)
                    let name = String(data: nameData, encoding: .utf8) ?? ""

                    var entryDataProvider: DataProvider? = nil
                    if loadFileData {
                        let fileAbsoluteOffset = fileDataBaseOffset + offset
                        entryDataProvider = { requestedOffset, requestedSize in
                            guard requestedOffset + UInt64(requestedSize) <= size else {
                                throw ParserError.dataOutOfBounds(reason: "Read request for file '\(name)' is out of its bounds.")
                            }
                            return try dataProvider(fileAbsoluteOffset + requestedOffset, requestedSize)
                        }
                    }

                    fileEntries.append(PFS0FileEntry(
                        offset: offset, size: size, stringTableOffset: stringTableRelOffset,
                        hashedSize: hashedSize, reserved: entryReserved, hash: hash,
                        name: name, dataProvider: entryDataProvider
                    ))
                }
                return PFS0Partition(header: header, files: fileEntries)
            }
        }
    }
}