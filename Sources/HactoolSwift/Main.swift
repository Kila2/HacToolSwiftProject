import Foundation
import ArgumentParser

@main
struct HactoolSwift: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hactool-swift",
        abstract: "A Swift tool to inspect and extract Nintendo Switch file formats."
    )
    
    @Option(name: .shortAndLong, help: "Path to your 'prod.keys' file.")
    var keyset: String
    
    @Option(name: .shortAndLong, help: "Input file type [nca, nsp, xci].")
    var type: String
    
    @Option(name: .shortAndLong, help: "Output format for console [pretty, json]. Default is pretty.")
    var outputFormat: String = "pretty"
    
    @Option(name: .long, help: "Directory to extract files to.")
    var outdir: String?
    
    @Option(name: .long, help: "Path to write JSON output to. Overrides other console output.")
    var json: String?
    
    @Option(name: .long, help: "For XCI, specify which partition to process [root, update, normal, secure]. Default is to extract all partitions.")
    var partition: String?
    
    @Argument(help: "The input file path.")
    var filePath: String
    
    // Marked as @escaping to fix compiler error
    private func processPFS0(dataProvider: @escaping DataProvider) throws -> (PrettyPrintable & JSONSerializable)? {
        let partition = try PFS0Parser.parse(dataProvider: dataProvider)
        if let outdirPath = self.outdir {
            try partition.extractFiles(to: FileExtractor(outputDirectory: URL(fileURLWithPath: outdirPath)))
        }
        return partition
    }
    
    // Marked as @escaping to fix compiler error
    private func processXCI(dataProvider: @escaping DataProvider) throws -> (PrettyPrintable & JSONSerializable)? {
        let parser = XCIParser(dataProvider: dataProvider)
        try parser.parse()

        if let outdirPath = self.outdir {
            let outputDirectoryURL = URL(fileURLWithPath: outdirPath)

            if let requestedPartitionName = self.partition?.lowercased() {
                print("Attempting to extract user-specified partition: '\(requestedPartitionName)'...")
                if let partition = parser.partitions[requestedPartitionName] {
                    if partition.content.files.isEmpty {
                        print("Partition '\(requestedPartitionName)' is empty. Nothing to extract.")
                    } else {
                        let extractor = FileExtractor(outputDirectory: outputDirectoryURL.appendingPathComponent(partition.name))
                        print("  -> Outputting to subdirectory: '\(partition.name)'")
                        try partition.content.extractFiles(to: extractor)
                    }
                } else {
                    print("Error: Partition '\(requestedPartitionName)' not found in the XCI file.")
                }
            } else {
                print("Extracting all found partitions to '\(outdirPath)'...")
                let partitionOrder = ["root", "update", "normal", "secure", "logo"]
                var foundPartitions = false

                for name in partitionOrder {
                    if let partition = parser.partitions[name] {
                        if partition.content.files.isEmpty { continue }
                        
                        foundPartitions = true
                        print("\n--- Extracting '\(name)' partition ---")
                        let partitionOutputDir = outputDirectoryURL.appendingPathComponent(partition.name)
                        let extractor = FileExtractor(outputDirectory: partitionOutputDir)
                        print("  -> Outputting to subdirectory: '\(partition.name)'")
                        try partition.content.extractFiles(to: extractor)
                    }
                }
                
                if foundPartitions {
                    print("\nAll non-empty partitions extracted.")
                } else {
                    print("No non-empty partitions found to extract.")
                }
            }
        }
        return parser
    }

    private func processNCA(dataProvider: @escaping DataProvider, keyset: Keyset) throws -> (PrettyPrintable & JSONSerializable)? {
        let parser = NCAParser(dataProvider: dataProvider, keyset: keyset)
        try parser.parse()
        if let outdirPath = self.outdir {
            let extractor = FileExtractor(outputDirectory: URL(fileURLWithPath: outdirPath))
            for i in 0..<4 where parser.header.sectionEntries[i].size > 0 {
                print("\nExtracting Section \(i)...")
                try parser.extractSection(i, to: extractor)
            }
        }
        return parser
    }

    func run() throws {
        var keyset: Keyset? = nil
        if !self.keyset.isEmpty {
            let loadedKeyset = Keyset()
            do {
                try loadedKeyset.load(from: URL(fileURLWithPath: self.keyset))
                try loadedKeyset.deriveKeys()
                keyset = loadedKeyset
            } catch {
                print("Error loading or deriving keys: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
       
        let fileURL = URL(fileURLWithPath: filePath)
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            print("Error: Failed to open file for reading at \(filePath)")
            throw ExitCode.failure
        }
        defer {
            try? fileHandle.close()
        }

        let dataProvider: DataProvider = { (offset: UInt64, size: Int) throws -> Data in
            if #available(macOS 13.0, *) {
                try fileHandle.seek(toOffset: offset)
            } else {
                fileHandle.seek(toFileOffset: offset)
            }
            guard let data = try fileHandle.read(upToCount: size), data.count == size else {
                 throw ParserError.dataOutOfBounds(reason: "Failed to read \(size) bytes at offset \(offset).")
            }
            return data
        }
        
        var parsedObject: (PrettyPrintable & JSONSerializable)?
        
        do {
            switch type.lowercased() {
            case "nca":
                guard let keyset = keyset else {
                    print("Error: --keyset is required for NCA parsing.")
                    throw ExitCode.failure
                }
                parsedObject = try processNCA(dataProvider: dataProvider, keyset: keyset)
            case "nsp":
                parsedObject = try processPFS0(dataProvider: dataProvider)
            case "xci":
                parsedObject = try processXCI(dataProvider: dataProvider)
            default:
                print("Error: Unsupported file type '\(type)'. Supported types are: nca, nsp, xci.")
                throw ExitCode.failure
            }
        } catch {
            print("An error occurred during parsing: \(error.localizedDescription)")
            throw ExitCode.failure
        }

        if let object = parsedObject {
            if let jsonPath = self.json {
                print("Writing JSON output to \(jsonPath)...")
                try OutputFormatter.writeJSON(object, to: URL(fileURLWithPath: jsonPath), includeData: true)
                print("JSON output complete.")
            } 
            else if outdir == nil {
                switch outputFormat.lowercased() {
                case "json":
                    try OutputFormatter.printJSON(object)
                default:
                    OutputFormatter.prettyPrint(object)
                }
            }
        }
    }
}