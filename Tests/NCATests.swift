import XCTest
@testable import HactoolSwift

final class NCATests: XCTestCase {
    var keyset: Keyset!
    var ncaData: Data!

    override func setUpWithError() throws {
        // This test requires a valid prod.keys file and a sample NCA.
        let keysURL = URL(fileURLWithPath: "prod.keys")
        guard FileManager.default.fileExists(atPath: keysURL.path) else {
            throw XCTSkip("prod.keys not found in project root. Cannot run NCA tests.")
        }
        keyset = Keyset()
        try keyset.load(from: keysURL)
        try keyset.deriveKeys()
        
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "nca", subdirectory: "Resources") else {
            throw XCTSkip("Test NCA file 'sample.nca' not found in Tests/Resources/ folder.")
        }
        ncaData = try Data(contentsOf: url)
    }

    func testNCAParsingAndDecryption() throws {
        let parser = NCAParser(data: ncaData, keyset: keyset)
        try parser.parse()

        XCTAssertEqual(parser.header.magic, "NCA3")
        XCTAssertNotEqual(parser.header.titleId, 0)
        
        // Attempt to read from the first valid section to test decryption stream
        guard let sectionIndex = parser.header.sectionEntries.firstIndex(where: { $0.size > 0 }) else {
            throw XCTSkip("Test NCA has no valid sections.")
        }
        
        let section = parser.header.sectionEntries[sectionIndex]
        guard section.size >= 16 else {
            throw XCTSkip("Test NCA section \(sectionIndex) is too small for a read test.")
        }
        
        let decryptedBytes = try parser.readDecryptedData(sectionIndex: sectionIndex, offset: 0, size: 16)
        XCTAssertEqual(decryptedBytes.count, 16)
        
        // A simple sanity check: if decryption failed spectacularly, it might still be all zeros or all FFs.
        // A properly decrypted block is unlikely to be this.
        XCTAssertNotEqual(decryptedBytes, Data(repeating: 0, count: 16))
        XCTAssertNotEqual(decryptedBytes, Data(repeating: 0xFF, count: 16))
    }
}
