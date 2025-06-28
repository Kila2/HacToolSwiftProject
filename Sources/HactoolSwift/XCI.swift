import Foundation

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
            self.header = try XCIHeader.parse(from: headerBuffer);
        }
        
        let rootHfs0Offset = header.hfs0Offset
        let rootHfs0Size = header.hfs0HeaderSize

        guard rootHfs0Offset > 0 && rootHfs0Size > 0 else {
            throw ParserError.unknownFormat("Root HFS0 partition has zero offset or size in XCI header.")
        }
        
        let rootPartitionMap = try PFS0Parser.parse(dataProvider: dataProvider, baseOffset: rootHfs0Offset, magic: "HFS0", loadFileData: false)
        self.partitions["root"] = XCIPartition(name: "root", offset: rootHfs0Offset, content: rootPartitionMap)

        let rootMapHeaderSize = 16 + (Int(rootPartitionMap.header.numFiles) * 64) + Int(rootPartitionMap.header.stringTableSize)

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
        output += String(format: "\(indent)Cartridge Size:                     %012llx\n", header.cartSizeRaw)

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
                output += "\(subIndent)Number of files:                \(content.header.numFiles)\n"
                
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
