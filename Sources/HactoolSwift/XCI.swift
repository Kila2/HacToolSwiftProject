import Foundation

struct XCIHeader {
    let headerSig: Data
    let magic: String
    let cartType: UInt8
    let rawCartSize: UInt64
    let reversedIV: Data
    let hfs0Offset: UInt64
    let hfs0HeaderSize: UInt64
    let encryptedData: Data

    var iv: Data {
        return Data(reversedIV.reversed())
    }

    var cartridgeTypeString: String {
        switch cartType {
        case 0xFA: return "1GB"; case 0xF8: return "2GB"; case 0xF0: return "4GB";
        case 0xE0: return "8GB"; case 0xE1: return "16GB"; case 0xE2: return "32GB"
        default: return "Unknown/Invalid"
        }
    }
    
    var cartridgeSizeValue: UInt64 {
        return (rawCartSize + 1) * 512
    }
}

struct XCIPartition {
    let name: String
    let offset: UInt64
    let content: PFS0Partition
}

class XCIParser: PrettyPrintable, JSONSerializable {
    let dataProvider: DataProvider
    var header: XCIHeader!
    var partitions: [String: XCIPartition] = [:]
    
    var securePartition: PFS0Partition? {
        return partitions["secure"]?.content
    }

    init(dataProvider: @escaping DataProvider) {
        self.dataProvider = dataProvider
    }
    
    func parse() throws {
        let headerData = try dataProvider(0, 0x200)

        // FIXED: Explicitly type the buffer parameter
        try headerData.withUnsafeBytes { (headerBuffer: UnsafeRawBufferPointer) in
            let magicRaw: UInt32 = try readLE(from: headerBuffer, at: 0x100)
            let magicData = withUnsafeBytes(of: magicRaw) { Data($0) }
            guard let magicString = String(data: magicData, encoding: .ascii), magicString == "HEAD" else {
                throw ParserError.invalidMagic(expected: "HEAD", found: String(data: magicData, encoding: .ascii) ?? "Unreadable")
            }

            // Creating a Data slice is efficient (no copy) for long-term storage in the struct.
            // We'll use Data() to create a copy from the slice.
            self.header = XCIHeader(
                headerSig: Data(headerBuffer[0x0..<0x100]),
                magic: magicString,
                cartType: try readLE(from: headerBuffer, at: 0x10D),
                rawCartSize: try readLE(from: headerBuffer, at: 0x118),
                reversedIV: Data(headerBuffer[0x120..<0x130]),
                hfs0Offset: try readLE(from: headerBuffer, at: 0x130),
                hfs0HeaderSize: try readLE(from: headerBuffer, at: 0x138),
                encryptedData: Data(headerBuffer[0x190..<0x200])
            )
        }
        
        let rootHfs0Offset = header.hfs0Offset
        let rootHfs0Size = header.hfs0HeaderSize

        guard rootHfs0Offset > 0 && rootHfs0Size > 0 else {
            throw ParserError.unknownFormat("Root HFS0 partition has zero offset or size in XCI header.")
        }
        
        let rootPartitionMap = try PFS0Parser.parse(dataProvider: dataProvider, baseOffset: rootHfs0Offset, magic: "HFS0", loadFileData: false)
        self.partitions["root"] = XCIPartition(name: "root", offset: rootHfs0Offset, content: rootPartitionMap)

        let rootMapHeaderSize = 16 + (Int(rootPartitionMap.header.fileCount) * 64) + Int(rootPartitionMap.header.stringTableSize)

        for fileEntry in rootPartitionMap.files {
            let partitionName = fileEntry.name.lowercased().replacingOccurrences(of: ".hfs0", with: "")
            if ["update", "normal", "secure", "logo"].contains(partitionName) {
                
                let partitionAbsoluteOffset = rootHfs0Offset + UInt64(rootMapHeaderSize) + fileEntry.offset
                let partitionSize = fileEntry.size
                
                guard partitionSize > 0 else { continue }
                
                do {
                    let contentPartition = try PFS0Parser.parse(dataProvider: dataProvider, baseOffset: partitionAbsoluteOffset, magic: "HFS0")
                    self.partitions[partitionName] = XCIPartition(name: partitionName, offset: partitionAbsoluteOffset, content: contentPartition)
                } catch {
                     print("Warning: Failed to parse partition '\(partitionName)'. It might be corrupt. Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func toPrettyString(indent: String) -> String {
        guard let header = header else { return "XCI has not been parsed." }

        var output = "\(indent)XCI:\n"
        output += "\(indent)Magic:                              \(header.magic)\n"
        
        let sig = header.headerSig.hexEncodedString().uppercased()
        let sigLines = stride(from: 0, to: sig.count, by: 64).map {
            String(sig[sig.index(sig.startIndex, offsetBy: $0)..<sig.index(sig.startIndex, offsetBy: min($0 + 64, sig.count))])
        }
        output += "\(indent)Header Signature:                   \(sigLines.joined(separator: "\n\(indent)                                    "))\n"
        
        output += "\(indent)Cartridge Type:                     \(header.cartridgeTypeString)\n"
        output += String(format: "\(indent)Cartridge Size:                     %012llx\n", header.cartridgeSizeValue)

        output += "\(indent)Header IV:                          \(header.iv.hexEncodedString().uppercased())\n"
        
        let encData = header.encryptedData.hexEncodedString().uppercased()
        let encLines = stride(from: 0, to: encData.count, by: 64).map {
            String(encData[encData.index(encData.startIndex, offsetBy: $0)..<encData.index(encData.startIndex, offsetBy: min($0 + 64, encData.count))])
        }
        output += "\(indent)Encrypted Header:                   \(encLines.joined(separator: "\n\(indent)                                    "))\n"
        
        output += "\(indent)Encrypted Header Data:\n"
        output += "\(indent)    Compatibility Type:             Global\n"

        let partitionOrder = ["root", "update", "normal", "secure", "logo"]
        for name in partitionOrder {
            if let partition = partitions[name] {
                output += "\(indent)\(name.capitalized) Partition:\n"
                
                let subIndent = "  " + indent
                let content = partition.content
                
                let magicData = withUnsafeBytes(of: content.header.magic) { Data($0) }
                let magicString = String(data: magicData, encoding: .ascii) ?? "????"
                
                output += "\(subIndent)Magic:                          \(magicString)\n"
                output += String(format: "\(subIndent)Offset:                         %012llx\n", partition.offset)
                output += "\(subIndent)Number of files:                \(content.header.fileCount)\n"
                
                if !content.files.isEmpty {
                    let filesHeader = "\(subIndent)Files:                          "
                    let filesIndent = String(repeating: " ", count: filesHeader.count)
                    
                    for (i, entry) in content.files.enumerated() {
                        let linePrefix = (i == 0) ? filesHeader : filesIndent
                        
                        let partitionDisplayName = (partition.name == "root") ? "rootpt" : partition.name
                        let fullName = "\(partitionDisplayName):/\(entry.name)"
                        
                        let paddedName = fullName.padding(toLength: 56, withPad: " ", startingAt: 0)
                        let startOffset = entry.offset
                        let endOffset = entry.offset + entry.size
                        output += String(format: "%@%@ %012llx-%012llx\n", linePrefix, paddedName, startOffset, endOffset)
                    }
                }
            }
        }
        
        return output
    }
    
    func toJSONObject(includeData: Bool) -> Any {
        let partitionJSON = partitions.mapValues { $0.content.toJSONObject(includeData: includeData) }
        return [ "type": "XCI", "partitions": partitionJSON ]
    }
}