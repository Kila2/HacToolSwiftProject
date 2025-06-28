//
//  Structs.swift
//  HactoolSwift
//
//  Created by kila on 2025/6/29.
//


// Sources/HactoolSwift/Structs.swift

import Foundation

// MARK: - 1. hfs0_header_t
/// HFS0 (Horizon File System 0) 的头部结构。
/// 来源: hfs0.h
struct HFS0Header {
    static let size = 16
    
    /// 魔术字，应为 "HFS0" (0x30534648)。
    let magic: UInt32
    /// HFS0 分区中的文件数量。
    let numFiles: UInt32
    /// 存储所有文件名的字符串表的大小（字节）。
    let stringTableSize: UInt32
    /// 保留字段，通常为 0。
    let reserved: UInt32

    /// 从不安全的原始缓冲区解析 HFS0Header。
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> HFS0Header {
        return HFS0Header(
            magic: try readLE(from: buffer, at: offset + 0),
            numFiles: try readLE(from: buffer, at: offset + 4),
            stringTableSize: try readLE(from: buffer, at: offset + 8),
            reserved: try readLE(from: buffer, at: offset + 12)
        )
    }
}

// MARK: - 2. pfs0_header_t
/// PFS0 (Partition File System 0) 的头部结构。
/// 来源: pfs0.h
struct PFS0Header {
    static let size = 16
    
    /// 魔术字，应为 "PFS0" (0x30534650)。
    let magic: UInt32
    /// PFS0 分区中的文件数量。
    let numFiles: UInt32
    /// 存储所有文件名的字符串表的大小（字节）。
    let stringTableSize: UInt32
    /// 保留字段，通常为 0。
    let reserved: UInt32

    /// 从不安全的原始缓冲区解析 PFS0Header。
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> PFS0Header {
        return PFS0Header(
            magic: try readLE(from: buffer, at: offset + 0),
            numFiles: try readLE(from: buffer, at: offset + 4),
            stringTableSize: try readLE(from: buffer, at: offset + 8),
            reserved: try readLE(from: buffer, at: offset + 12)
        )
    }
}

// MARK: - 3. ini1_header_t
/// INI1 (Initialiser 1) 格式的头部。
/// 来源: kip.h
struct INI1Header {
    static let fixedSize = 16
    
    /// 魔术字，应为 "INI1" (0x31494E49)。
    let magic: UInt32
    /// INI1 结构的总大小。
    let size: UInt32
    /// KIP1 进程的数量。
    let numProcesses: UInt32
    /// 保留字段。
    let reserved: UInt32
    
    // 注意: `kip_data` 是柔性数组成员，不在此头部解析。

    /// 从不安全的原始缓冲区解析 INI1Header。
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> INI1Header {
        return INI1Header(
            magic: try readLE(from: buffer, at: offset + 0),
            size: try readLE(from: buffer, at: offset + 4),
            numProcesses: try readLE(from: buffer, at: offset + 8),
            reserved: try readLE(from: buffer, at: offset + 12)
        )
    }
}

// MARK: - 4. kip1_header_t
/// KIP1 (Kernel Initial Process 1) 的头部结构。
/// 来源: kip.h
struct KIP1Header {
    static let fixedSize = 256
    
    /// KIP1 段头部信息，定义了 .text, .rodata, .data 等段的内存布局和大小。
    struct SectionHeader {
        static let size = 16
        
        /// 段在进程内存中的偏移量。
        let memoryOffset: UInt32
        /// 段的大小（字节）。
        let size: UInt32
        /// 段在 KIP1 文件中的偏移量。
        let fileOffset: UInt32
        /// 段的属性（例如：0=unmapped, 1=code, 2=rodata, 3=rwdata）。
        let attribute: UInt32
        
        /// 从不安全的原始缓冲区解析 SectionHeader。
        static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> SectionHeader {
            return SectionHeader(
                memoryOffset: try readLE(from: buffer, at: offset + 0),
                size:         try readLE(from: buffer, at: offset + 4),
                fileOffset:   try readLE(from: buffer, at: offset + 8),
                attribute:    try readLE(from: buffer, at: offset + 12)
            )
        }
    }
    
    /// 魔术字，应为 "KIP1" (0x3150494B)。
    let magic: UInt32
    /// 进程名称。
    let name: String
    /// 进程的 Title ID。
    let titleId: UInt64
    /// 进程分类。
    let processCategory: UInt32
    /// 主线程的优先级。
    let mainThreadPriority: UInt8
    /// 默认运行的 CPU 核心 ID。
    let defaultCore: UInt8
    /// 保留字段。
    let reserved0x1E: UInt8
    /// 标志位。
    let flags: UInt8
    /// 6 个段的头部信息数组。
    let sectionHeaders: [SectionHeader]
    /// 内核访问控制能力描述符。
    let capabilities: [UInt32]
    
    // 注意: `data` 是柔性数组成员，不在此头部解析。

    /// 从不安全的原始缓冲区解析 KIP1Header。
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> KIP1Header {
        // 解析 `name` 字段
        let nameData = Data(buffer[offset+4 ..< offset+16])
        let nameString = String(data: nameData, encoding: .ascii)?.trimmingCharacters(in: ["\0"]) ?? ""
        
        // 解析 6 个 `sectionHeaders`
        var sections: [SectionHeader] = []
        sections.reserveCapacity(6)
        for i in 0..<6 {
            let sectionOffset = offset + 32 + (i * SectionHeader.size)
            sections.append(try SectionHeader.parse(from: buffer, at: sectionOffset))
        }

        // 解析 `capabilities` 数组
        var caps: [UInt32] = []
        caps.reserveCapacity(32)
        for i in 0..<32 {
            caps.append(try readLE(from: buffer, at: offset + 128 + i * 4))
        }

        return KIP1Header(
            magic: try readLE(from: buffer, at: offset + 0),
            name: nameString,
            titleId: try readLE(from: buffer, at: offset + 16),
            processCategory: try readLE(from: buffer, at: offset + 24),
            mainThreadPriority: try readLE(from: buffer, at: offset + 28),
            defaultCore: try readLE(from: buffer, at: offset + 29),
            reserved0x1E: try readLE(from: buffer, at: offset + 30),
            flags: try readLE(from: buffer, at: offset + 31),
            sectionHeaders: sections,
            capabilities: caps
        )
    }
}

// MARK: - 5. npdm_t
/// NPDM (Nintendo Program Data Manifest) 结构。
/// 来源: npdm.h
struct NPDMHeader {
    static let size = 128
    
    /// 魔术字，应为 "META" (0x4154454D)。
    let magic: UInt32
    /// ACID 签名使用的密钥索引。
    let acidSignKeyIndex: UInt32
    let reserved0x8: UInt32
    /// MMU (内存管理单元) 标志。
    let mmuFlags: UInt8
    let reserved0xD: UInt8
    /// 主线程优先级。
    let mainThreadPrio: UInt8
    /// 默认 CPU 核心 ID。
    let defaultCpuid: UInt8
    let reserved0x10: UInt64
    /// NPDM 版本号。
    let version: UInt32
    /// 主线程堆栈大小。
    let mainStackSize: UInt32
    /// 标题名称。
    let titleName: String
    /// ACI0 结构的偏移量。
    let aci0Offset: UInt32
    /// ACI0 结构的大小。
    let aci0Size: UInt32
    /// ACID 结构的偏移量。
    let acidOffset: UInt32
    /// ACID 结构的大小。
    let acidSize: UInt32

    /// 从不安全的原始缓冲区解析 NPDMHeader。
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> NPDMHeader {
        let nameData = Data(buffer[offset+32 ..< offset+112])
        let nameString = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: ["\0"]) ?? ""
        
        return NPDMHeader(
            magic: try readLE(from: buffer, at: offset + 0),
            acidSignKeyIndex: try readLE(from: buffer, at: offset + 4),
            reserved0x8: try readLE(from: buffer, at: offset + 8),
            mmuFlags: try readLE(from: buffer, at: offset + 12),
            reserved0xD: try readLE(from: buffer, at: offset + 13),
            mainThreadPrio: try readLE(from: buffer, at: offset + 14),
            defaultCpuid: try readLE(from: buffer, at: offset + 15),
            reserved0x10: try readLE(from: buffer, at: offset + 16),
            version: try readLE(from: buffer, at: offset + 24),
            mainStackSize: try readLE(from: buffer, at: offset + 28),
            titleName: nameString,
            aci0Offset: try readLE(from: buffer, at: offset + 112),
            aci0Size: try readLE(from: buffer, at: offset + 116),
            acidOffset: try readLE(from: buffer, at: offset + 120),
            acidSize: try readLE(from: buffer, at: offset + 124)
        )
    }
}

// MARK: - 6. nca_keyset_t
/// 运行时结构，用于存储从外部文件加载的所有密钥。
/// 注意: 这不是文件格式，因此不提供 `parse` 方法。
/// 来源: settings.h
struct NCAKeyset {
    // 此结构非常庞大，仅定义部分关键字段作为示例。
    // 在实际应用中，Keyset.swift 类动态管理这些密钥。
    var secureBootKey: Data
    var tsecKey: Data
    var masterKeks: [Data]
    var masterKeys: [Data]
    var headerKey: Data
    var keyAreaKeys: [[Data]]
}

// MARK: - 7. nca_header_t
/// NCA (Nintendo Content Archive) 文件的头部结构。
/// 来源: nca.h
struct NCAHeader {
    static let size = 3072
    
    enum NCAContentType: UInt8, CustomStringConvertible, Codable, Equatable {
        case program = 0, meta, control, manual, data, publicData
        var description: String {
            switch self {
            case .program: "Program"; case .meta: "Meta"; case .control: "Control"
            case .manual: "Manual"; case .data: "Data"; case .publicData: "PublicData"
            }
        }
    }


    enum NCAEncryptionType: UInt8, CustomStringConvertible, Codable, Equatable {
        case none = 0
        case xts = 1
        case ctr = 2
        case bktr = 4
        
        var description: String {
            switch self {
            case .none: "None"; case .xts: "AES-XTS"; case .ctr: "AES-CTR"; case .bktr: "BKTR/Patch"
            }
        }
    }
    /// 用于表示 SDK 版本号的 Union。
    struct SDKVersion {
        let rawValue: UInt32
        var revision: UInt8 { UInt8(truncatingIfNeeded: rawValue) }
        var micro: UInt8 { UInt8(truncatingIfNeeded: rawValue >> 8) }
        var minor: UInt8 { UInt8(truncatingIfNeeded: rawValue >> 16) }
        var major: UInt8 { UInt8(truncatingIfNeeded: rawValue >> 24) }
        var string: String { "\(major).\(minor).\(micro).\(revision)" }
    }

    struct SectionEntry {
        static let size = 16
        
        let mediaOffset: UInt32
        let mediaEndOffset: UInt32
        let reserved: UInt64
        
        var size: UInt64 {
            guard mediaEndOffset > mediaOffset else { return 0 }
            return UInt64(mediaEndOffset - mediaOffset) * 0x200
        }
        
        var startOffsetBytes: UInt64 {
            return UInt64(mediaOffset) * 0x200
        }

        static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> SectionEntry {
            return SectionEntry(
                mediaOffset: try readLE(from: buffer, at: offset + 0),
                mediaEndOffset: try readLE(from: buffer, at: offset + 4),
                reserved: try readLE(from: buffer, at: offset + 8)
            )
        }
    }

    /// 使用固定密钥对头部的 RSA-PSS 签名。
    let fixedKeySig: Data
    /// 使用 NPDM 中密钥对头部的 RSA-PSS 签名。
    let npdmKeySig: Data
    /// 魔术字 "NCA3", "NCA2" 或 "NCA0"。
    let magic: UInt32
    /// 分发类型（0=数字版, 1=卡带版）。
    let distribution: UInt8
    /// 内容类型。
    let contentType: NCAContentType
    /// 主密钥修订版本。
    let cryptoType: NCAEncryptionType
    /// 使用的密钥区域加密密钥（KAEK）的索引。
    let kaekInd: UInt8
    /// 整个 NCA 文件的大小。
    let ncaSize: UInt64
    /// 关联的 Title ID。
    let titleId: UInt64
    /// 编译此 NCA 的 SDK 版本。
    let sdkVersion: SDKVersion
    /// 第二个主密钥修订版本。
    let cryptoType2: UInt8
    /// 用于签名验证的固定密钥的代数。
    let fixedKeyGeneration: UInt8
    /// Rights ID，用于 titlekey 加密。
    let rightsId: Data
    /// 4 个分区的条目信息。
    let sectionEntries: [SectionEntry]
    /// 每个文件系统（FS）头部的 SHA-256 哈希。
    let sectionHashes: [Data]
    /// 加密的密钥区域 (Key Area)。
    let encryptedKeys: [Data]
    /// 4 个文件系统头部。
    let fsHeaders: [NCAFileSystemHeader]

    /// 从不安全的原始缓冲区解析 NCAHeader。
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> NCAHeader {
        var sections: [SectionEntry] = []
        var hashes: [Data] = []
        var keys: [Data] = []
        var headers: [NCAFileSystemHeader] = []
        
        sections.reserveCapacity(4)
        hashes.reserveCapacity(4)
        keys.reserveCapacity(4)
        headers.reserveCapacity(4)

        for i in 0..<4 {
            let entryOffset = offset + 0x240 + i * SectionEntry.size
            sections.append(try SectionEntry.parse(from: buffer, at: entryOffset))
            
            let hashOffset = offset + 0x280 + i * 32
            hashes.append(Data(buffer[hashOffset ..< hashOffset + 32]))
            
            let keyOffset = offset + 0x300 + i * 16
            keys.append(Data(buffer[keyOffset ..< keyOffset + 16]))
            
            let fsHeaderOffset = offset + 0x400 + i * NCAFileSystemHeader.size
            headers.append(try NCAFileSystemHeader.parse(from: buffer, at: fsHeaderOffset))
        }

        let contentTypeRaw: UInt8 = try readLE(from: buffer, at: offset + 0x205)
        guard let contentType = NCAContentType(rawValue: contentTypeRaw) else {
            throw ParserError.unknownFormat("Invalid NCA Content Type: \(contentTypeRaw)")
        }
        
        let cryptoTypeRaw: UInt8 = try readLE(from: buffer, at: offset + 0x206)
        guard let cryptoType = NCAEncryptionType(rawValue: cryptoTypeRaw) else {
            throw ParserError.unknownFormat("Invalid NCA Crypto Type: \(contentTypeRaw)")
        }

        return NCAHeader(
            fixedKeySig: Data(buffer[offset+0x000 ..< offset+0x100]),
            npdmKeySig: Data(buffer[offset+0x100 ..< offset+0x200]),
            magic: try readLE(from: buffer, at: offset + 0x200),
            distribution: try readLE(from: buffer, at: offset + 0x204),
            contentType: contentType,
            cryptoType: cryptoType,
            kaekInd: try readLE(from: buffer, at: offset + 0x207),
            ncaSize: try readLE(from: buffer, at: offset + 0x208),
            titleId: try readLE(from: buffer, at: offset + 0x210),
            sdkVersion: .init(rawValue: try readLE(from: buffer, at: offset + 0x21C)),
            cryptoType2: try readLE(from: buffer, at: offset + 0x220),
            fixedKeyGeneration: try readLE(from: buffer, at: offset + 0x221),
            rightsId: Data(buffer[offset+0x230 ..< offset+0x240]),
            sectionEntries: sections,
            sectionHashes: hashes,
            encryptedKeys: keys,
            fsHeaders: headers
        )
    }
}

// MARK: - 8. nca_fs_header_t
/// NCA 中每个分区的头部结构。
/// 来源: nca.h
struct NCAFileSystemHeader {
    static let size = 512
    
    enum FSType: UInt8, CustomStringConvertible {
        case pfs0 = 2, romfs = 3
        var description: String {
            switch self { case .pfs0: "PFS0"; case .romfs: "RomFS" }
        }
    }
    
    enum CryptType: UInt8, CustomStringConvertible {
        case none = 1, xts = 2, ctr = 3, bktr = 4
        var description: String {
            switch self { case .none: "None"; case .xts: "AES-XTS"; case .ctr: "AES-CTR"; case .bktr: "BKTR/Patch" }
        }
    }
    
    let partitionType: UInt8
    let fsType: FSType?
    let cryptType: CryptType?
    let superblock: Data
    let sectionCtr: UInt64
    
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> NCAFileSystemHeader {
        return NCAFileSystemHeader(
            partitionType: try readLE(from: buffer, at: offset + 0x02),
            fsType: FSType(rawValue: try readLE(from: buffer, at: offset + 0x03)),
            cryptType: CryptType(rawValue: try readLE(from: buffer, at: offset + 0x04)),
            superblock: Data(buffer[offset+0x08 ..< offset+0x140]),
            sectionCtr: try readLE(from: buffer, at: offset + 0x140)
        )
    }
}

// MARK: - 9. nca_section_ctx_t
/// 运行时上下文结构，不是文件格式。
/// 来源: nca.h
struct NCASectionContext {
    let isPresent: Bool
    let offset: UInt64
    let size: UInt64
    let sectionNum: UInt32
}

// MARK: - 10. nca0_romfs_hdr_t
/// 早期 Beta 版游戏的 RomFS 头部结构。
/// 来源: nca0_romfs.h
struct NCA0RomFSHeader {
    static let size = 40
    
    let headerSize: UInt32
    let dirHashTableOffset: UInt32
    let dirHashTableSize: UInt32
    let dirMetaTableOffset: UInt32
    let dirMetaTableSize: UInt32
    let fileHashTableOffset: UInt32
    let fileHashTableSize: UInt32
    let fileMetaTableOffset: UInt32
    let fileMetaTableSize: UInt32
    let dataOffset: UInt32

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> NCA0RomFSHeader {
        return .init(
            headerSize: try readLE(from: buffer, at: offset + 0),
            dirHashTableOffset: try readLE(from: buffer, at: offset + 4),
            dirHashTableSize: try readLE(from: buffer, at: offset + 8),
            dirMetaTableOffset: try readLE(from: buffer, at: offset + 12),
            dirMetaTableSize: try readLE(from: buffer, at: offset + 16),
            fileHashTableOffset: try readLE(from: buffer, at: offset + 20),
            fileHashTableSize: try readLE(from: buffer, at: offset + 24),
            fileMetaTableOffset: try readLE(from: buffer, at: offset + 28),
            fileMetaTableSize: try readLE(from: buffer, at: offset + 32),
            dataOffset: try readLE(from: buffer, at: offset + 36)
        )
    }
}

// MARK: - 11. nso0_header_t
/// NSO0 (Nintendo Switch Object 0) 文件的头部。
/// 来源: nso.h
struct NSO0Header {
    static let fixedSize = 256
    
    struct Segment {
        static let size = 16
        let fileOffset: UInt32
        let memoryOffset: UInt32
        let size: UInt32
        let reserved: UInt32
        
        static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> Segment {
            return .init(
                fileOffset: try readLE(from: buffer, at: offset + 0),
                memoryOffset: try readLE(from: buffer, at: offset + 4),
                size: try readLE(from: buffer, at: offset + 8),
                reserved: try readLE(from: buffer, at: offset + 12)
            )
        }
    }

    let magic: UInt32
    let flags: UInt32
    let segments: [Segment]
    let buildId: Data
    let compressedSizes: (UInt32, UInt32, UInt32)
    let dynstrExtents: UInt64
    let dynsymExtents: UInt64
    let sectionHashes: [Data]

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> NSO0Header {
        var segs: [Segment] = []
        segs.reserveCapacity(3)
        for i in 0..<3 {
            segs.append(try Segment.parse(from: buffer, at: offset + 16 + i * Segment.size))
        }
        
        return .init(
            magic: try readLE(from: buffer, at: offset + 0),
            flags: try readLE(from: buffer, at: offset + 12),
            segments: segs,
            buildId: Data(buffer[offset+64 ..< offset+96]),
            compressedSizes: (
                try readLE(from: buffer, at: offset + 96),
                try readLE(from: buffer, at: offset + 100),
                try readLE(from: buffer, at: offset + 104)
            ),
            dynstrExtents: try readLE(from: buffer, at: offset + 144),
            dynsymExtents: try readLE(from: buffer, at: offset + 152),
            sectionHashes: [
                Data(buffer[offset+160 ..< offset+192]),
                Data(buffer[offset+192 ..< offset+224]),
                Data(buffer[offset+224 ..< offset+256])
            ]
        )
    }
}

// MARK: - 12. pk11_mariko_oem_header_t
/// `Package1` 文件在 Mariko 平台上的 OEM 头部。
/// 来源: packages.h
struct PK11MarikoOEMHeader {
    static let size = 368

    let aesMac: Data
    let rsaSig: Data
    let salt: Data
    let hash: Data
    let blVersion: UInt32
    let blSize: UInt32
    let blLoadAddr: UInt32
    let blEntrypoint: UInt32
    
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> PK11MarikoOEMHeader {
        return .init(
            aesMac: Data(buffer[offset+0 ..< offset+16]),
            rsaSig: Data(buffer[offset+16 ..< offset+272]),
            salt: Data(buffer[offset+272 ..< offset+304]),
            hash: Data(buffer[offset+304 ..< offset+336]),
            blVersion: try readLE(from: buffer, at: offset + 336),
            blSize: try readLE(from: buffer, at: offset + 340),
            blLoadAddr: try readLE(from: buffer, at: offset + 344),
            blEntrypoint: try readLE(from: buffer, at: offset + 348)
        )
    }
}

// MARK: - 13. pk11_metadata_t
/// `Package1` 文件的元数据部分。
/// 来源: packages.h
struct PK11Metadata {
    static let size = 32

    let ldrHash: UInt32
    let smHash: UInt32
    let blHash: UInt32
    let reserved: UInt32
    let buildDate: String
    let version: UInt8

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> PK11Metadata {
        let dateData = Data(buffer[offset+16 ..< offset+30])
        let dateString = String(data: dateData, encoding: .ascii)?.trimmingCharacters(in: ["\0"]) ?? ""
        
        return .init(
            ldrHash: try readLE(from: buffer, at: offset + 0),
            smHash: try readLE(from: buffer, at: offset + 4),
            blHash: try readLE(from: buffer, at: offset + 8),
            reserved: try readLE(from: buffer, at: offset + 12),
            buildDate: dateString,
            version: try readLE(from: buffer, at: offset + 31)
        )
    }
}

// MARK: - 16. pk11_t
/// `Package1` 的核心载荷。
/// 来源: packages.h
struct PK11PayloadHeader {
    static let fixedSize = 32

    let magic: UInt32
    let wbSize: UInt32
    let wbEp: UInt32
    let reserved: UInt32
    let blSize: UInt32
    let blEp: UInt32
    let smSize: UInt32
    let smEp: UInt32
    
    // 注意: `data` 是柔性数组成员，不在此头部解析。

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> PK11PayloadHeader {
        return .init(
            magic: try readLE(from: buffer, at: offset + 0),
            wbSize: try readLE(from: buffer, at: offset + 4),
            wbEp: try readLE(from: buffer, at: offset + 8),
            reserved: try readLE(from: buffer, at: offset + 12),
            blSize: try readLE(from: buffer, at: offset + 16),
            blEp: try readLE(from: buffer, at: offset + 20),
            smSize: try readLE(from: buffer, at: offset + 24),
            smEp: try readLE(from: buffer, at: offset + 28)
        )
    }
}

// MARK: - 17. pk21_header_t
/// `Package2` 的头部。
/// 注意: 此结构是紧密打包的 (`#pragma pack(push, 1)`).
/// 来源: packages.h
struct PK21Header {
    static let size = 512

    let signature: Data
    let ctr: Data
    let sectionCtrs: [Data]
    let magic: UInt32
    let baseOffset: UInt32
    let reserved: UInt32
    let versionMax: UInt8
    let versionMin: UInt8
    let sectionSizes: (UInt32, UInt32, UInt32, UInt32)
    let sectionOffsets: (UInt32, UInt32, UInt32, UInt32)
    let sectionHashes: [Data]

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> PK21Header {
        return .init(
            signature: Data(buffer[offset+0x0 ..< offset+0x100]),
            ctr: Data(buffer[offset+0x100 ..< offset+0x110]),
            sectionCtrs: [
                Data(buffer[offset+0x110 ..< offset+0x120]),
                Data(buffer[offset+0x120 ..< offset+0x130]),
                Data(buffer[offset+0x130 ..< offset+0x140]),
                Data(buffer[offset+0x140 ..< offset+0x150])
            ],
            magic: try readLE(from: buffer, at: offset + 0x150),
            baseOffset: try readLE(from: buffer, at: offset + 0x154),
            reserved: try readLE(from: buffer, at: offset + 0x158),
            versionMax: try readLE(from: buffer, at: offset + 0x15C),
            versionMin: try readLE(from: buffer, at: offset + 0x15D),
            sectionSizes: (
                try readLE(from: buffer, at: offset + 0x160), try readLE(from: buffer, at: offset + 0x164),
                try readLE(from: buffer, at: offset + 0x168), try readLE(from: buffer, at: offset + 0x16C)
            ),
            sectionOffsets: (
                try readLE(from: buffer, at: offset + 0x170), try readLE(from: buffer, at: offset + 0x174),
                try readLE(from: buffer, at: offset + 0x178), try readLE(from: buffer, at: offset + 0x17C)
            ),
            sectionHashes: [
                Data(buffer[offset+0x180 ..< offset+0x1A0]),
                Data(buffer[offset+0x1A0 ..< offset+0x1C0]),
                Data(buffer[offset+0x1C0 ..< offset+0x1E0]),
                Data(buffer[offset+0x1E0 ..< offset+0x200])
            ]
        )
    }
}


// MARK: - 18. romfs_hdr_t
/// RomFS 的头部结构。
/// 来源: ivfc.h
struct RomFSHeader {
    static let size = 80
    
    let headerSize: UInt64
    let dirHashTableOffset: UInt64
    let dirHashTableSize: UInt64
    let dirMetaTableOffset: UInt64
    let dirMetaTableSize: UInt64
    let fileHashTableOffset: UInt64
    let fileHashTableSize: UInt64
    let fileMetaTableOffset: UInt64
    let fileMetaTableSize: UInt64
    let dataOffset: UInt64

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> RomFSHeader {
        return .init(
            headerSize: try readLE(from: buffer, at: offset + 0),
            dirHashTableOffset: try readLE(from: buffer, at: offset + 8),
            dirHashTableSize: try readLE(from: buffer, at: offset + 16),
            dirMetaTableOffset: try readLE(from: buffer, at: offset + 24),
            dirMetaTableSize: try readLE(from: buffer, at: offset + 32),
            fileHashTableOffset: try readLE(from: buffer, at: offset + 40),
            fileHashTableSize: try readLE(from: buffer, at: offset + 48),
            fileMetaTableOffset: try readLE(from: buffer, at: offset + 56),
            fileMetaTableSize: try readLE(from: buffer, at: offset + 64),
            dataOffset: try readLE(from: buffer, at: offset + 72)
        )
    }
}


// MARK: - 19. save_header_t
/// Switch 存档文件的头部结构。
/// 注意: 此结构是紧密打包的 (`#pragma pack(push, 1)`).
/// 来源: save.h
struct SaveHeader {
    static let size = 16384 // 0x4000
    
    let cmac: Data
    // 此结构非常复杂，包含许多嵌套结构。
    // 这里仅提供一个高层级的解析，实际应用需要解析内部的
    // fs_layout_t, duplex_header_t, ivfc_save_hdr_t 等。
    let layout: Data
    
    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> SaveHeader {
        return .init(
            cmac: Data(buffer[offset+0x0 ..< offset+0x10]),
            layout: Data(buffer[offset+0x100 ..< offset+0x300])
            // ... 更多字段的解析
        )
    }
}


// MARK: - 21. xci_header_t
/// XCI (Game Card Image) 文件的头部结构。
/// 来源: xci.h
struct XCIHeader {
    static let size = 512
    
    let headerSig: Data
    let magic: UInt32
    let secureOffset: UInt32
    let cartType: UInt8
    let cartSizeRaw: UInt64
    let reversedIV: Data
    let hfs0Offset: UInt64
    let hfs0HeaderSize: UInt64
    let hfs0HeaderHash: Data
    let cryptoHeaderHash: Data
    let encryptedData: Data

    static func parse(from buffer: UnsafeRawBufferPointer, at offset: Int = 0) throws -> XCIHeader {
        return .init(
            headerSig: Data(buffer[offset+0x000 ..< offset+0x100]),
            magic: try readLE(from: buffer, at: offset + 0x100),
            secureOffset: try readLE(from: buffer, at: offset + 0x104),
            cartType: try readLE(from: buffer, at: offset + 0x10D),
            cartSizeRaw: try readLE(from: buffer, at: offset + 0x118),
            reversedIV: Data(buffer[offset+0x120 ..< offset+0x130]),
            hfs0Offset: try readLE(from: buffer, at: offset + 0x130),
            hfs0HeaderSize: try readLE(from: buffer, at: offset + 0x138),
            hfs0HeaderHash: Data(buffer[offset+0x140 ..< offset+0x160]),
            cryptoHeaderHash: Data(buffer[offset+0x160 ..< offset+0x180]),
            encryptedData: Data(buffer[offset+0x190 ..< offset+0x200])
        )
    }
    
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
    
    var cartridgeSize: UInt64 {
        return (cartSizeRaw + 1) * 512
    }
}
