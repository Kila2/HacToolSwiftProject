import Foundation

protocol PrettyPrintable {
    func toPrettyString(indent: String) -> String
}

protocol JSONSerializable {
    func toJSONObject(includeData: Bool) -> Any
}

enum OutputFormatter {
    static func prettyPrint(_ item: PrettyPrintable) {
        print(item.toPrettyString(indent: ""))
    }
    
    private static func getJSONData(_ item: JSONSerializable, includeData: Bool) throws -> Data {
        let jsonObject = item.toJSONObject(includeData: includeData)
        return try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
    }

    static func printJSON(_ item: JSONSerializable) throws {
        let jsonData = try getJSONData(item, includeData: false)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    static func writeJSON(_ item: JSONSerializable, to url: URL, includeData: Bool) throws {
        let jsonData = try getJSONData(item, includeData: includeData)
        try jsonData.write(to: url)
    }
}
