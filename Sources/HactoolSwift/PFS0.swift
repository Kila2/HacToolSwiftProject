import Foundation

// --- Data Models (Value Types) ---
struct PFS0Header {
    let magic: UInt32, fileCount: UInt32, stringTableSize: UInt32, reserved: UInt32
}

struct PFS0FileEntry {
    let offset: UInt64, size: UInt64, stringTableOffset: UInt32
    let hashedSize: UInt32, reserved: UInt64, hash: Data
    let name: String
    var data: Data // Data might be empty if not loaded
}

// Represents a fully parsed, immutable PFS0/HFS0 partition
struct PFS0Partition: PrettyPrintable, JSONSerializable {
    let header: PFS0Header
    let files: [PFS0FileEntry]
    
    // Restored to conform to PrettyPrintable protocol
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
            if includeData && !entry.data.isEmpty { fileJSON["data_base64"] = entry.data.base64EncodedString() }
            return fileJSON
        }
        let magicData = withUnsafeBytes(of: header.magic) { Data($0) }
        let magicString = String(data: magicData, encoding: .ascii) ?? "????"
        return [ "type": magicString, "file_count": header.fileCount, "string_table_size": header.stringTableSize, "files": filesJSON ]
    }

    func extractFiles(to extractor: FileExtractor) throws {
        print("Extracting \(files.count) files from PFS0/HFS0...")
        for entry in files {
            guard !entry.data.isEmpty else {
                print("  - Skipping \(entry.name): File data was not loaded during parsing.")
                continue
            }
            try extractor.extract(path: entry.name, data: entry.data)
        }
        print("Extraction complete.")
    }
}

// --- Parser (Stateless) ---
enum PFS0Parser {
    static func parse(data: Data, magic: String = "PFS0", loadFileData: Bool = true) throws -> PFS0Partition {
        guard data.count >= 16 else { throw ParserError.fileTooShort(reason: "Data is smaller than a PFS0/HFS0 header.") }
        let readMagic: UInt32 = try readLE(from: data, at: 0)
        let magicData = withUnsafeBytes(of: readMagic) { Data($0) }
        guard let magicString = String(data: magicData, encoding: .ascii), magicString == magic else {
            throw ParserError.invalidMagic(expected: magic, found: String(data: magicData, encoding: .ascii) ?? "Unreadable")
        }
        
        let fileCount: UInt32 = try readLE(from: data, at: 4)
        let stringTableSize: UInt32 = try readLE(from: data, at: 8)
        let reserved: UInt32 = try readLE(from: data, at: 12)
        let header = PFS0Header(magic: readMagic, fileCount: fileCount, stringTableSize: stringTableSize, reserved: reserved)

        let isHFS0 = (magic == "HFS0")
        let entrySize = isHFS0 ? 64 : 24

        let fileEntryTableOffset = 16
        let fileEntryTableSize = Int(fileCount) * entrySize
        let stringTableOffset = fileEntryTableOffset + fileEntryTableSize
        let fileDataBaseOffset = stringTableOffset + Int(stringTableSize)
        
        var fileEntries: [PFS0FileEntry] = []

        for i in 0..<Int(fileCount) {
            let currentEntryBaseOffset = fileEntryTableOffset + (i * entrySize)
            guard data.count >= currentEntryBaseOffset + entrySize else {
                throw ParserError.fileTooShort(reason: "Not enough data for file entry \(i).")
            }

            let offset: UInt64 = try readLE(from: data, at: currentEntryBaseOffset + 0)
            let size: UInt64 = try readLE(from: data, at: currentEntryBaseOffset + 8)
            let stringTableRelOffset: UInt32 = try readLE(from: data, at: currentEntryBaseOffset + 16)
            
            var hashedSize: UInt32 = 0
            var entryReserved: UInt64 = 0
            var hash = Data()

            if isHFS0 {
                hashedSize = try readLE(from: data, at: currentEntryBaseOffset + 20)
                entryReserved = try readLE(from: data, at: currentEntryBaseOffset + 24)
                hash = data.subdata(in: (currentEntryBaseOffset + 32)..<(currentEntryBaseOffset + 64))
            } else { // PFS0
                hashedSize = try readLE(from: data, at: currentEntryBaseOffset + 20)
            }

            let nameAbsoluteOffset = stringTableOffset + Int(stringTableRelOffset)
            guard nameAbsoluteOffset < fileDataBaseOffset else {
                throw ParserError.dataOutOfBounds(reason: "Filename offset for entry \(i) (relative: \(stringTableRelOffset)) points outside of string table.")
            }
            var end = nameAbsoluteOffset
            while end < fileDataBaseOffset && data[end] != 0 { end += 1 }
            let nameData = data.subdata(in: nameAbsoluteOffset..<end)
            let name = String(data: nameData, encoding: .utf8) ?? ""

            var fileData = Data()
            if loadFileData {
                let fileAbsoluteOffset = fileDataBaseOffset + Int(offset)
                let fileSize = Int(size)
                guard fileAbsoluteOffset + fileSize <= data.count else {
                    throw ParserError.dataOutOfBounds(reason: "File '\(name)' data (offset: \(fileAbsoluteOffset), size: \(fileSize)) is out of bounds for total data size \(data.count).")
                }
                fileData = data.subdata(in: fileAbsoluteOffset..<(fileAbsoluteOffset + fileSize))
            }

            fileEntries.append(PFS0FileEntry(
                offset: offset, size: size, stringTableOffset: stringTableRelOffset,
                hashedSize: hashedSize, reserved: entryReserved, hash: hash,
                name: name, data: fileData
            ))
        }
        
        return PFS0Partition(header: header, files: fileEntries)
    }
}