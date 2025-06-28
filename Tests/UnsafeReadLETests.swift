//
//  UnsafeReadLETests.swift
//  HactoolSwift
//
//  Created by kila on 2025/6/28.
//


import Testing
import Foundation
@testable import HactoolSwift // 替换为你的项目名

@Suite("UnsafeRawBufferPointer Little-Endian Read Utility Tests")
struct UnsafeReadLETests {

    // 准备一个包含多种数据类型的测试数据块
    // 字节布局 (小端序):
    // 0-3:   UInt32 -> 0x04030201
    // 4-5:   UInt16 -> 0xBBAA
    // 6-13:  UInt64 -> 0x8877665544332211
    // 14:    UInt8  -> 0xFF
    let testData = Data([
        0x01, 0x02, 0x03, 0x04, // UInt32
        0xAA, 0xBB,             // UInt16
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, // UInt64
        0xFF                    // UInt8
    ])

    @Test("Should correctly read UInt32 from a buffer pointer")
    func testReadUInt32() throws {
        try testData.withUnsafeBytes { buffer in
            let value: UInt32 = try readLE(from: buffer, at: 0)
            #expect(value == 0x04030201, "Failed to read UInt32 correctly.")
        }
    }

    @Test("Should correctly read UInt16 from a buffer pointer")
    func testReadUInt16() throws {
        try testData.withUnsafeBytes { buffer in
            let value: UInt16 = try readLE(from: buffer, at: 4)
            #expect(value == 0xBBAA, "Failed to read UInt16 correctly.")
        }
    }

    @Test("Should correctly read UInt64 from a buffer pointer")
    func testReadUInt64() throws {
        try testData.withUnsafeBytes { buffer in
            let value: UInt64 = try readLE(from: buffer, at: 6)
            #expect(value == 0x8877665544332211, "Failed to read UInt64 correctly.")
        }
    }

    @Test("Should correctly read UInt8 from a buffer pointer")
    func testReadUInt8() throws {
        try testData.withUnsafeBytes { buffer in
            let value: UInt8 = try readLE(from: buffer, at: 14)
            #expect(value == 0xFF, "Failed to read UInt8 correctly.")
        }
    }

    @Test("Should throw error when reading beyond buffer bounds")
    func testReadOutOfBounds() throws {
        // 1. 准备预期的错误。这个实例的类型是 ParserError。
        let expectedError = ParserError.dataOutOfBounds(
            reason: "Read for \(UInt64.self) at offset 10 out of bounds for buffer size 15."
        )
        
        // 2. 这个宏需要比较两个 ParserError 实例，所以 ParserError 必须是 Equatable。
        #expect(throws: expectedError, "...") {
            try testData.withUnsafeBytes { buffer in
                _ = try readLE(from: buffer, at: 10) as UInt64
            }
        }
    }
    
    @Test("Should throw error when offset itself is out of bounds")
    func testReadAtInvalidOffset() throws {
        try testData.withUnsafeBytes { buffer in
            #expect(throws: ParserError.self, "Reading at an invalid offset should throw a ParserError.") {
                _ = try readLE(from: buffer, at: 20) as UInt32
            }
        }
    }
    
    @Test("Should throw error when offset is negative")
    func testReadAtNegativeOffset() throws {
        try testData.withUnsafeBytes { buffer in
            #expect(throws: ParserError.self, "Reading at a negative offset should throw a ParserError.") {
                _ = try readLE(from: buffer, at: -1) as UInt32
            }
        }
    }

    @Test("Should succeed when reading at the exact end of buffer")
    func testReadAtBoundary_Success() throws {
        // 这个测试只验证成功的情况
        try testData.withUnsafeBytes { buffer in
            // 直接调用，不包裹 #expect(throws:)
            // 如果出错，测试会因未捕获的异常而失败
            let value: UInt8 = try readLE(from: buffer, at: 14)
            #expect(value == 0xFF)
        }
    }
    
    @Test("Should fail when reading past the exact end of buffer")
    func testReadAtBoundary_Failure() throws {
        // 这个测试只验证失败的情况
        let expectedError = ParserError.dataOutOfBounds(
            reason: "Read for \(UInt16.self) at offset 14 out of bounds for buffer size 15."
        )
        
        // 将 #expect(throws:) 包裹在最外层
        #expect(throws: expectedError) {
            try testData.withUnsafeBytes { buffer in
                _ = try readLE(from: buffer, at: 14) as UInt16
            }
        }
    }
}
