import XCTest
@testable import HactoolSwift

final class XCITests: XCTestCase {
    func testXCIParser() throws {
        // To run this test, you must place a small, valid XCI file named `sample.xci`
        // inside the Tests/Resources/ directory.
        guard let url = Bundle.module.url(forResource: "sample", withExtension: "xci", subdirectory: "Resources") else {
            throw XCTSkip("Test XCI file 'sample.xci' not found in Tests/Resources/ folder.")
        }
        
        let xciData = try Data(contentsOf: url)
        let parser = XCIParser(data: xciData)
        
        try parser.parse()
        
        XCTAssertNotNil(parser.partitions["root"])
        XCTAssertNotNil(parser.partitions["secure"])
        
        let rootContent = parser.partitions["root"]!.content
        let secureContent = parser.partitions["secure"]!.content
        
        let rootMagicData = withUnsafeBytes(of: rootContent.header.magic) { Data($0) }
        let rootMagicString = String(data: rootMagicData, encoding: .ascii)
        XCTAssertEqual(rootMagicString, "HFS0")

        let secureMagicData = withUnsafeBytes(of: secureContent.header.magic) { Data($0) }
        let secureMagicString = String(data: secureMagicData, encoding: .ascii)
        XCTAssertEqual(secureMagicString, "HFS0")
    }
}
