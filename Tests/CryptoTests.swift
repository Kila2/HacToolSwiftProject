import XCTest
@testable import HactoolSwift

final class CryptoTests: XCTestCase {

    // MARK: - Test Vectors

    // AES-128 ECB Test Vector (from NIST SP 800-38A)
    let ecbKey = Data(fromHex: "2b7e151628aed2a6abf7158809cf4f3c")!
    let ecbPlaintext = Data(fromHex: "6bc1bee22e409f96e93d7e117393172a")!
    let ecbCiphertext = Data(fromHex: "3ad77bb40d7a3660a89ecaf32466ef97")!
    
    // AES-128 CTR Test Vector (from NIST SP 800-38A)
    let ctrKey = Data(fromHex: "2b7e151628aed2a6abf7158809cf4f3c")!
    let ctrIV = Data(fromHex: "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")!
    let ctrPlaintext = Data(fromHex: "6bc1bee22e409f96e93d7e117393172a" + "ae2d8a571e03ac9c9eb76fac45af8e51")! // Two blocks
    let ctrCiphertext = Data(fromHex: "874d6191b620e3261bef6864990db6ce" + "9806f66b7970fdff8617187bb9fffdff")!

    // AES-256 XTS Test Vector (from IEEE P1619, adapted for little-endian tweak)
    let xtsKey = Data(fromHex: "000102030405060708090a0b0c0d0e0f" + "101112131415161718191a1b1c1d1e1f")!
    let xtsTweak = Data(fromHex: "01000000000000000000000000000000")!
    let xtsPlaintext = Data(fromHex: "000102030405060708090a0b0c0d0e0f")!
    let xtsCiphertext = Data(fromHex: "c68c1f83565022364a4751463132717a")!

    // MARK: - AES-ECB Tests

    func testAesEcbEncrypt() throws {
        let encrypted = try Crypto.aesEcbEncrypt(key: ecbKey, data: ecbPlaintext)
        XCTAssertEqual(encrypted.hexEncodedString(), ecbCiphertext.hexEncodedString())
    }

    func testAesEcbDecrypt() throws {
        let decrypted = try Crypto.aesEcbDecrypt(key: ecbKey, data: ecbCiphertext)
        XCTAssertEqual(decrypted.hexEncodedString(), ecbPlaintext.hexEncodedString())
    }

    // MARK: - AES-CTR Tests (Validating the manual implementation)

    func testManualAesCtrCrypt_Encrypt() throws {
        let encrypted = try Crypto.aesCtrCrypt(key: ctrKey, iv: ctrIV, data: ctrPlaintext)
        XCTAssertEqual(encrypted.hexEncodedString(), ctrCiphertext.hexEncodedString(), "Manual AES-CTR encryption result is incorrect.")
    }

    func testManualAesCtrCrypt_Decrypt() throws {
        let decrypted = try Crypto.aesCtrCrypt(key: ctrKey, iv: ctrIV, data: ctrCiphertext)
        XCTAssertEqual(decrypted.hexEncodedString(), ctrPlaintext.hexEncodedString(), "Manual AES-CTR decryption result is incorrect.")
    }
    
    // MARK: - AES-XTS Tests (Validating the manual implementation)
    
    func testManualAesXtsDecrypt() throws {
        let decrypted = try Crypto.aesXtsDecrypt(keyData: xtsKey, tweakData: xtsTweak, data: xtsCiphertext, sectorSize: 16)
        XCTAssertEqual(decrypted.hexEncodedString(), xtsPlaintext.hexEncodedString(), "Manual AES-XTS decryption is incorrect.")
    }
    
    // MARK: - GF128 Multiplication Test (Validating the manual implementation)
    
    func testGf128MultAlpha() {
        var input1 = Data(repeating: 0, count: 16)
        input1[0] = 0x01
        var expected1 = Data(repeating: 0, count: 16)
        expected1[0] = 0x02
        let result1 = GF128.xts_gf_mult_alpha(input1)
        XCTAssertEqual(result1, expected1, "GF(128) multiplication by alpha (no overflow) is incorrect.")
        
        var input2 = Data(repeating: 0, count: 16)
        input2[0] = 0x80
        var expected2 = Data(repeating: 0, count: 16)
        expected2[0] = 0x87 // After shift left and XOR with feedback
        let result2 = GF128.xts_gf_mult_alpha(input2)
        XCTAssertEqual(result2, expected2, "GF(128) multiplication by alpha (with overflow/feedback) is incorrect.")
    }
    
    func testGf128Mult() {
        var base = Data(repeating: 0, count: 16)
        base[0] = 1
        
        // base * alpha^1
        let mult1 = GF128.xts_gf_mult(base, by: 1)
        var expected1 = Data(repeating: 0, count: 16)
        expected1[0] = 2
        XCTAssertEqual(mult1, expected1)

        // base * alpha^2
        let mult2 = GF128.xts_gf_mult(base, by: 2)
        var expected2 = Data(repeating: 0, count: 16)
        expected2[0] = 4
        XCTAssertEqual(mult2, expected2)
        
        // base * alpha^7 (0x01 -> 0x80)
        let mult7 = GF128.xts_gf_mult(base, by: 7)
        var expected7 = Data(repeating: 0, count: 16)
        expected7[0] = 0x80
        XCTAssertEqual(mult7, expected7)

        // base * alpha^8 (0x80 -> 0x87)
        let mult8 = GF128.xts_gf_mult(base, by: 8)
        var expected8 = Data(repeating: 0, count: 16)
        expected8[0] = 0x87
        XCTAssertEqual(mult8, expected8, "GF(128) multiplication by power is incorrect.")
    }
}