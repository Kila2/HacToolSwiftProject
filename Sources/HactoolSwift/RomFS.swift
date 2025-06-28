import Foundation

enum RomFSError: Error, CustomStringConvertible {
    case unexpectedEndOfData
    case unexpectedEndOfDataForName
    
    var description: String {
        switch self {
        case .unexpectedEndOfData: "unexpected end of data"
        case .unexpectedEndOfDataForName: "unexpected end of data for name"
        }
    }
}

struct RomFSDirectoryEntry {
    let parent: UInt32, sibling: UInt32, child: UInt32, file: UInt32, hash: UInt32, nameSize: UInt32
    var name: String = ""
}

struct RomFSFileEntry {
    let parent: UInt32, sibling: UInt32
    let offset: UInt64, size: UInt64
    let hash: UInt32, nameSize: UInt32
    var name: String = ""
}

class RomFSParser: PrettyPrintable, JSONSerializable {
    typealias DataProvider = (UInt64, Int) throws -> Data
    
    let dataProvider: DataProvider
    var header: RomFSHeader!
    var directories: [RomFSDirectoryEntry] = []
    var files: [RomFSFileEntry] = []
    
    init(dataProvider: @escaping DataProvider) {
        self.dataProvider = dataProvider
    }
    
    func parse() throws {
        // --- Header ---
        let headerData = try dataProvider(0, 64)
        // This is a special case. RomFS header fields are already little-endian in memory if read as a block.
        // We need to swap them to host byte order.
        let rawHeader = headerData.withUnsafeBytes { $0.load(as: RomFSHeader.self) }
        self.header = RomFSHeader(
            headerSize: rawHeader.headerSize.littleEndian,
            dirHashTableOffset: rawHeader.dirHashTableOffset.littleEndian,
            dirHashTableSize: rawHeader.dirHashTableSize.littleEndian,
            dirMetaTableOffset: rawHeader.dirMetaTableOffset.littleEndian,
            dirMetaTableSize: rawHeader.dirMetaTableSize.littleEndian,
            fileHashTableOffset: rawHeader.fileHashTableOffset.littleEndian,
            fileHashTableSize: rawHeader.fileHashTableSize.littleEndian,
            fileMetaTableOffset: rawHeader.fileMetaTableOffset.littleEndian,
            fileMetaTableSize: rawHeader.fileMetaTableSize.littleEndian,
            dataOffset: rawHeader.dataOffset.littleEndian
        )
        
        // --- Directories ---
        let dirMetaData = try dataProvider(header.dirMetaTableOffset, Int(header.dirMetaTableSize))
        var directories: [RomFSDirectoryEntry] = [] // 确保这个数组在这里被初始化或已存在
        // 使用 withUnsafeBytes 来获取 UnsafeRawBufferPointer
        try dirMetaData.withUnsafeBytes { buffer in
            var currentOffset = 0
            while currentOffset < buffer.count {
                // 确保有足够的空间读取固定大小的部分 (24 bytes)
                guard currentOffset + 24 <= buffer.count else {
                    throw RomFSError.unexpectedEndOfData // 数据不完整
                }
                
                let parent: UInt32 = try readLE(from: buffer, at: currentOffset)
                let sibling: UInt32 = try readLE(from: buffer, at: currentOffset + 4)
                let child: UInt32 = try readLE(from: buffer, at: currentOffset + 8)
                let file: UInt32 = try readLE(from: buffer, at: currentOffset + 12)
                let hash: UInt32 = try readLE(from: buffer, at: currentOffset + 16)
                let nameSize: UInt32 = try readLE(from: buffer, at: currentOffset + 20)
                
                var dir = RomFSDirectoryEntry(parent: parent, sibling: sibling, child: child, file: file, hash: hash, nameSize: nameSize)
                
                let nameDataStart = currentOffset + 24
                let nameDataEnd = nameDataStart + Int(nameSize)
                
                // 确保有足够的空间读取名字数据
                guard nameDataEnd <= buffer.count else {
                    throw RomFSError.unexpectedEndOfDataForName // 名字数据不完整
                }
                
                // 对于 nameData，我们仍然可以使用原始的 Data 对象进行 subdata 操作，
                // 因为 Data.subdata 会返回一个新的 Data 对象，这比从 UnsafeRawBufferPointer
                // 重新构建 Data 更方便和安全。
                let nameData = dirMetaData.subdata(in: nameDataStart..<nameDataEnd)
                dir.name = String(data: nameData, encoding: .utf8) ?? ""
                directories.append(dir)
                
                currentOffset += (24 + Int(nameSize))
                // 对齐到4字节
                currentOffset = (currentOffset + 3) & ~3
            }
            // --- Files ---
            let fileMetaData = try dataProvider(header.fileMetaTableOffset, Int(header.fileMetaTableSize))
            currentOffset = 0
            while currentOffset < fileMetaData.count {
                let parent: UInt32 = try readLE(from: buffer, at: currentOffset)
                let sibling: UInt32 = try readLE(from: buffer, at: currentOffset + 4)
                let offset: UInt64 = try readLE(from: buffer, at: currentOffset + 8)
                let size: UInt64 = try readLE(from: buffer, at: currentOffset + 16)
                let hash: UInt32 = try readLE(from: buffer, at: currentOffset + 24)
                let nameSize: UInt32 = try readLE(from: buffer, at: currentOffset + 28)
                
                var file = RomFSFileEntry(parent: parent, sibling: sibling, offset: offset, size: size, hash: hash, nameSize: nameSize)
                
                let nameData = fileMetaData.subdata(in: (currentOffset + 32)..<(currentOffset + 32 + Int(nameSize)))
                file.name = String(data: nameData, encoding: .utf8) ?? ""
                files.append(file)
                
                currentOffset += (32 + Int(nameSize))
                currentOffset = (currentOffset + 3) & ~3 // Align to 4 bytes
            }
        }
    }
    
    private func buildFileTree(includeData: Bool) throws -> [String: Any] {
        var tree: [String: Any] = [:]
        try buildTreeRecursive(dirIndex: 0, currentPath: "", tree: &tree, includeData: includeData)
        return tree
    }
    
    private func buildTreeRecursive(dirIndex: Int, currentPath: String, tree: inout [String: Any], includeData: Bool) throws {
        guard dirIndex < directories.count else { return }
        let dirEntry = directories[dirIndex]
        
        if dirEntry.file != 0xFFFFFFFF {
            var currentFileIndex = Int(dirEntry.file)
            while currentFileIndex != -1 && currentFileIndex < files.count {
                let fileEntry = files[currentFileIndex]
                let filePath = currentPath + fileEntry.name
                var fileJSON: [String: Any] = ["type": "file", "size": fileEntry.size]
                if includeData {
                    let fileData = try dataProvider(header.dataOffset + fileEntry.offset, Int(fileEntry.size))
                    fileJSON["data_base64"] = fileData.base64EncodedString()
                }
                tree[filePath] = fileJSON
                
                if fileEntry.sibling == 0xFFFFFFFF { break }
                currentFileIndex = Int(fileEntry.sibling)
            }
        }
        
        if dirEntry.child != 0xFFFFFFFF {
            var currentChildIndex = Int(dirEntry.child)
            while currentChildIndex != -1 && currentChildIndex < directories.count {
                let childDir = directories[currentChildIndex]
                let newPath = currentPath + childDir.name + "/"
                var subTree: [String: Any] = [:]
                try buildTreeRecursive(dirIndex: currentChildIndex, currentPath: newPath, tree: &subTree, includeData: includeData)
                tree[childDir.name] = ["type": "directory", "content": subTree]
                
                if childDir.sibling == 0xFFFFFFFF { break }
                currentChildIndex = Int(childDir.sibling)
            }
        }
    }
    
    func toPrettyString(indent: String) -> String {
        guard header != nil else { return "\(indent)RomFS has not been parsed.\n" }
        return "\(indent)--- RomFS Summary ---\n\(indent)Directories: \(directories.count)\n\(indent)Files: \(files.count)\n\(indent)---------------------\n"
    }
    
    func toJSONObject(includeData: Bool) -> Any {
        guard header != nil else { return [:] }
        do {
            return try buildFileTree(includeData: includeData)
        } catch {
            return ["error": "Failed to build RomFS file tree: \(error.localizedDescription)"]
        }
    }
    
    func extractFiles(to extractor: FileExtractor) throws {
        print("Extracting RomFS content...")
        try extractRecursive(dirIndex: 0, currentPath: "", extractor: extractor)
        print("RomFS extraction complete.")
    }
    
    private func extractRecursive(dirIndex: Int, currentPath: String, extractor: FileExtractor) throws {
        guard dirIndex < directories.count else { return }
        let dirEntry = directories[dirIndex]
        
        if dirEntry.file != 0xFFFFFFFF {
            var currentFileIndex = Int(dirEntry.file)
            while currentFileIndex != -1 && currentFileIndex < files.count {
                let fileEntry = files[currentFileIndex]
                let fileData = try dataProvider(header.dataOffset + fileEntry.offset, Int(fileEntry.size))
                try extractor.extract(path: currentPath + fileEntry.name, data: fileData)
                if fileEntry.sibling == 0xFFFFFFFF { break }
                currentFileIndex = Int(fileEntry.sibling)
            }
        }
        
        if dirEntry.child != 0xFFFFFFFF {
            var currentChildIndex = Int(dirEntry.child)
            while currentChildIndex != -1 && currentChildIndex < directories.count {
                let childDir = directories[currentChildIndex]
                try extractRecursive(dirIndex: currentChildIndex, currentPath: currentPath + childDir.name + "/", extractor: extractor)
                if childDir.sibling == 0xFFFFFFFF { break }
                currentChildIndex = Int(childDir.sibling)
            }
        }
    }
}
