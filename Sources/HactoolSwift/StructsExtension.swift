// Sources/HactoolSwift/StructsExtension.swift

import Foundation

// MARK: - Formatting Helper
fileprivate func format(label: String, value: Any, indent: String) -> String {
    let paddedLabel = label.padding(toLength: 35, withPad: " ", startingAt: 0)
    return "\(indent)\(paddedLabel): \(value)\n"
}

fileprivate func formatHex<T: CVarArg & FixedWidthInteger>(_ value: T) -> String {
    return String(format: "0x%llX", value as! CVarArg)
}

fileprivate func formatData(_ data: Data, multilineIndent: String) -> String {
    let hex = data.hexEncodedString().uppercased()
    guard hex.count > 64 else { return hex }
    
    // Split into 64-character (32-byte) lines
    var lines: [String] = []
    var currentIndex = hex.startIndex
    while currentIndex < hex.endIndex {
        let endIndex = hex.index(currentIndex, offsetBy: 64, limitedBy: hex.endIndex) ?? hex.endIndex
        lines.append(String(hex[currentIndex..<endIndex]))
        currentIndex = endIndex
    }
    return lines.joined(separator: "\n" + multilineIndent)
}

// MARK: - Struct Conformances

extension HFS0Header: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "File Count", value: self.numFiles, indent: indent)
        output += format(label: "String Table Size", value: formatHex(self.stringTableSize), indent: indent)
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        return [
            "magic": String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???",
            "file_count": self.numFiles,
            "string_table_size": formatHex(self.stringTableSize)
        ]
    }
}

extension PFS0Header: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "File Count", value: self.numFiles, indent: indent)
        output += format(label: "String Table Size", value: formatHex(self.stringTableSize), indent: indent)
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        return [
            "magic": String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???",
            "file_count": self.numFiles,
            "string_table_size": formatHex(self.stringTableSize)
        ]
    }
}

extension INI1Header: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Size", value: formatHex(self.size), indent: indent)
        output += format(label: "Number of Processes", value: self.numProcesses, indent: indent)
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        return [
            "magic": String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???",
            "size": formatHex(self.size),
            "process_count": self.numProcesses
        ]
    }
}

extension KIP1Header: PrettyPrintable, JSONSerializable {
    private func attributeToString(_ attr: UInt32) -> String {
        switch attr {
        case 0: return "Unmapped"
        case 1: return "Code"
        case 2: return "ROData"
        case 3: return "RWData"
        default: return "Unknown (\(attr))"
        }
    }

    func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Name", value: self.name, indent: indent)
        output += format(label: "Title ID", value: String(format: "%016llX", self.titleId), indent: indent)
        output += format(label: "Process Category", value: self.processCategory, indent: indent)
        output += "\(indent)Section Headers:\n"
        for (i, section) in self.sectionHeaders.enumerated() {
            output += "\(indent)  Section \(i):\n"
            output += format(label: "    Attribute", value: attributeToString(section.attribute), indent: indent)
            output += format(label: "    Memory Offset", value: formatHex(section.memoryOffset), indent: indent)
            output += format(label: "    File Offset", value: formatHex(section.fileOffset), indent: indent)
            output += format(label: "    Size", value: formatHex(section.size), indent: indent)
        }
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        let sectionsJSON = self.sectionHeaders.map { section -> [String: Any] in
            return [
                "attribute": attributeToString(section.attribute),
                "attribute_raw": section.attribute,
                "memory_offset": formatHex(section.memoryOffset),
                "file_offset": formatHex(section.fileOffset),
                "size": formatHex(section.size)
            ]
        }
        
        return [
            "magic": "KIP1",
            "name": self.name,
            "title_id": String(format: "%016llX", self.titleId),
            "process_category": self.processCategory,
            "main_thread_priority": self.mainThreadPriority,
            "default_core": self.defaultCore,
            "flags": self.flags,
            "section_headers": sectionsJSON,
            "capabilities": self.capabilities.map { formatHex($0) }
        ]
    }
}

extension NPDMHeader: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Title Name", value: self.titleName, indent: indent)
        output += format(label: "Version", value: self.version, indent: indent)
        output += format(label: "Main Thread Prio", value: self.mainThreadPrio, indent: indent)
        output += format(label: "ACI0 Offset", value: formatHex(self.aci0Offset), indent: indent)
        output += format(label: "ACI0 Size", value: formatHex(self.aci0Size), indent: indent)
        output += format(label: "ACID Offset", value: formatHex(self.acidOffset), indent: indent)
        output += format(label: "ACID Size", value: formatHex(self.acidSize), indent: indent)
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        return [
            "magic": "META",
            "title_name": self.titleName,
            "version": self.version,
            "mmu_flags": self.mmuFlags,
            "main_thread_prio": self.mainThreadPrio,
            "default_cpuid": self.defaultCpuid,
            "aci0_offset": formatHex(self.aci0Offset),
            "aci0_size": formatHex(self.aci0Size),
            "acid_offset": formatHex(self.acidOffset),
            "acid_size": formatHex(self.acidSize)
        ]
    }
}

extension NCAHeader: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        let multilineIndent = indent + String(repeating: " ", count: 37)
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Content Type", value: self.contentType.description, indent: indent)
        output += format(label: "Title ID", value: String(format: "%016llX", self.titleId), indent: indent)
        output += format(label: "SDK Version", value: self.sdkVersion.string, indent: indent)
        output += format(label: "Master Key Revision", value: self.cryptoType, indent: indent)
        output += format(label: "NCA Size", value: formatHex(self.ncaSize), indent: indent)
        output += format(label: "Rights ID", value: self.rightsId.hexEncodedString(), indent: indent)
        
        output += "\(indent)Sections:\n"
        for i in 0..<4 {
            let entry = self.sectionEntries[i]
            if entry.size == 0 { continue }
            
            let fsHeader = self.fsHeaders[i]
            output += "\(indent)  Section \(i):\n"
            output += format(label: "    Offset", value: formatHex(entry.startOffsetBytes), indent: indent)
            output += format(label: "    Size", value: formatHex(entry.size), indent: indent)
            output += format(label: "    FS Type", value: fsHeader.fsType?.description ?? "Unknown", indent: indent)
            output += format(label: "    Crypto Type", value: fsHeader.cryptType?.description ?? "Unknown", indent: indent)
            output += format(label: "    CTR", value: formatHex(fsHeader.sectionCtr), indent: indent)
        }
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        var sectionsJSON: [[String: Any]] = []
        for i in 0..<4 {
            let entry = self.sectionEntries[i]
            if entry.size == 0 { continue }
            let fsHeader = self.fsHeaders[i]
            
            sectionsJSON.append([
                "index": i,
                "offset": formatHex(entry.startOffsetBytes),
                "size": formatHex(entry.size),
                "fs_type": fsHeader.fsType?.description ?? "Unknown",
                "fs_type_raw": fsHeader.fsType?.rawValue ?? 0,
                "crypto_type": fsHeader.cryptType?.description ?? "Unknown",
                "crypto_type_raw": fsHeader.cryptType?.rawValue ?? 0,
                "ctr": formatHex(fsHeader.sectionCtr)
            ])
        }
        
        return [
            "magic": String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???",
            "content_type": self.contentType.description,
            "title_id": String(format: "%016llX", self.titleId),
            "sdk_version": self.sdkVersion.string,
            "master_key_revision": self.cryptoType,
            "nca_size": formatHex(self.ncaSize),
            "rights_id": self.rightsId.hexEncodedString(),
            "sections": sectionsJSON
        ]
    }
}

extension NSO0Header: PrettyPrintable, JSONSerializable {
     func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Build ID", value: self.buildId.hexEncodedString(), indent: indent)
        
        output += "\(indent)Segments:\n"
        let segNames = ["Text", "ROData", "Data"]
        for (i, seg) in self.segments.enumerated() {
            output += "\(indent)  \(segNames[i]):\n"
            output += format(label: "    File Offset", value: formatHex(seg.fileOffset), indent: indent)
            output += format(label: "    Memory Offset", value: formatHex(seg.memoryOffset), indent: indent)
            output += format(label: "    Size", value: formatHex(seg.size), indent: indent)
        }
        return output
    }
    
    func toJSONObject(includeData: Bool) -> Any {
        let segmentsJSON = self.segments.map { seg -> [String: Any] in
            return [
                "file_offset": formatHex(seg.fileOffset),
                "memory_offset": formatHex(seg.memoryOffset),
                "size": formatHex(seg.size)
            ]
        }
        
        return [
            "magic": "NSO0",
            "build_id": self.buildId.hexEncodedString(),
            "segments": segmentsJSON,
            "compressed_sizes": [
                formatHex(self.compressedSizes.0),
                formatHex(self.compressedSizes.1),
                formatHex(self.compressedSizes.2)
            ]
        ]
    }
}

extension PK21Header: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        let multilineIndent = indent + String(repeating: " ", count: 37)
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Signature", value: formatData(self.signature, multilineIndent: multilineIndent), indent: indent)
        output += format(label: "CTR", value: self.ctr.hexEncodedString().uppercased(), indent: indent)
        output += format(label: "Base Offset", value: formatHex(self.baseOffset), indent: indent)
        output += "\(indent)Section Hashes:\n"
        for (i, hash) in self.sectionHashes.enumerated() {
            output += "\(indent)  Section \(i): \(hash.hexEncodedString().uppercased())\n"
        }
        return output
    }
    
    func toJSONObject(includeData: Bool) -> Any {
        return [
            "magic": "PK21",
            "signature": self.signature.hexEncodedString(),
            "ctr": self.ctr.hexEncodedString(),
            "base_offset": formatHex(self.baseOffset),
            "version_max": self.versionMax,
            "version_min": self.versionMin,
            "section_sizes": [formatHex(self.sectionSizes.0), formatHex(self.sectionSizes.1), formatHex(self.sectionSizes.2), formatHex(self.sectionSizes.3)],
            "section_offsets": [formatHex(self.sectionOffsets.0), formatHex(self.sectionOffsets.1), formatHex(self.sectionOffsets.2), formatHex(self.sectionOffsets.3)],
            "section_hashes": self.sectionHashes.map { $0.hexEncodedString() }
        ]
    }
}

extension RomFSHeader: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        var output = ""
        output += format(label: "Header Size", value: formatHex(self.headerSize), indent: indent)
        output += format(label: "Dir Hash Table Offset", value: formatHex(self.dirHashTableOffset), indent: indent)
        output += format(label: "Dir Hash Table Size", value: formatHex(self.dirHashTableSize), indent: indent)
        output += format(label: "Dir Meta Table Offset", value: formatHex(self.dirMetaTableOffset), indent: indent)
        output += format(label: "Dir Meta Table Size", value: formatHex(self.dirMetaTableSize), indent: indent)
        output += format(label: "File Hash Table Offset", value: formatHex(self.fileHashTableOffset), indent: indent)
        output += format(label: "File Hash Table Size", value: formatHex(self.fileHashTableSize), indent: indent)
        output += format(label: "File Meta Table Offset", value: formatHex(self.fileMetaTableOffset), indent: indent)
        output += format(label: "File Meta Table Size", value: formatHex(self.fileMetaTableSize), indent: indent)
        output += format(label: "Data Offset", value: formatHex(self.dataOffset), indent: indent)
        return output
    }
    
    func toJSONObject(includeData: Bool) -> Any {
        return [
            "header_size": formatHex(self.headerSize),
            "dir_hash_table_offset": formatHex(self.dirHashTableOffset),
            "dir_hash_table_size": formatHex(self.dirHashTableSize),
            "dir_meta_table_offset": formatHex(self.dirMetaTableOffset),
            "dir_meta_table_size": formatHex(self.dirMetaTableSize),
            "file_hash_table_offset": formatHex(self.fileHashTableOffset),
            "file_hash_table_size": formatHex(self.fileHashTableSize),
            "file_meta_table_offset": formatHex(self.fileMetaTableOffset),
            "file_meta_table_size": formatHex(self.fileMetaTableSize),
            "data_offset": formatHex(self.dataOffset)
        ]
    }
}

extension XCIHeader: PrettyPrintable, JSONSerializable {
    func toPrettyString(indent: String) -> String {
        let multilineIndent = indent + String(repeating: " ", count: 37)
        var output = ""
        output += format(label: "Magic", value: String(data: withUnsafeBytes(of: self.magic) { Data($0) }, encoding: .ascii) ?? "???", indent: indent)
        output += format(label: "Header Signature", value: formatData(self.headerSig, multilineIndent: multilineIndent), indent: indent)
        output += format(label: "Cartridge Type", value: "\(self.cartridgeTypeString) (\(formatHex(self.cartType)))", indent: indent)
        output += format(label: "Cartridge Size", value: formatHex(self.cartridgeSize), indent: indent)
        output += format(label: "IV", value: self.iv.hexEncodedString().uppercased(), indent: indent)
        output += format(label: "HFS0 Offset", value: formatHex(self.hfs0Offset), indent: indent)
        output += format(label: "HFS0 Size", value: formatHex(self.hfs0HeaderSize), indent: indent)
        return output
    }

    func toJSONObject(includeData: Bool) -> Any {
        return [
            "magic": "HEAD",
            "header_signature": self.headerSig.hexEncodedString(),
            "cartridge_type_string": self.cartridgeTypeString,
            "cartridge_type_raw": self.cartType,
            "cartridge_size": formatHex(self.cartridgeSize),
            "iv": self.iv.hexEncodedString(),
            "reversed_iv": self.reversedIV.hexEncodedString(),
            "hfs0_offset": formatHex(self.hfs0Offset),
            "hfs0_header_size": formatHex(self.hfs0HeaderSize),
            "hfs0_header_hash": self.hfs0HeaderHash.hexEncodedString(),
            "crypto_header_hash": self.cryptoHeaderHash.hexEncodedString(),
        ]
    }
}
