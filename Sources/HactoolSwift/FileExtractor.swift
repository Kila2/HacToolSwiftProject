import Foundation

class FileExtractor {
    let outputDirectory: URL
    
    init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }
    
    func extract(path: String, data: Data) throws {
        let fullPath = outputDirectory.appendingPathComponent(path)
        let directory = fullPath.deletingLastPathComponent()
        
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        
        try data.write(to: fullPath)
        print("  -> Extracted: \(path)")
    }
}
