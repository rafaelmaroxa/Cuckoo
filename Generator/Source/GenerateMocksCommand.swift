//
//  GenerateMocksCommand.swift
//  CuckooGenerator
//
//  Created by Tadeas Kriz on 12/01/16.
//  Copyright © 2016 Brightify. All rights reserved.
//

import Commandant
import Result
import SourceKittenFramework
import FileKit
import CuckooGeneratorFramework

private func curry<P1, P2, P3, P4, P5, P6, P7, R>(f: (P1, P2, P3, P4, P5, P6, P7) -> R)
    -> (P1) -> (P2) -> (P3) -> (P4) -> (P5) -> (P6) -> (P7) -> R {
        return { p1 in { p2 in { p3 in { p4 in { p5 in { p6 in { p7 in f(p1, p2, p3, p4, p5, p6, p7) } } } } } } }
}

public struct GenerateMocksCommand: CommandType {
    
    public let verb = "generate"
    public let function = "Generates mock files"
    
    public func run(options: Options) -> Result<Void, CuckooGeneratorError> {
        let tokens = options.files.map { File(path: $0) }.flatMap { $0 }.map { Tokenizer(sourceFile: $0).tokenize() }
        let parsedFiles = options.noClassMocking ? removeClasses(tokens) : tokens
        
        let headers = parsedFiles.map { options.noHeader ? "" : FileHeaderHandler.getHeader($0, withTimestamp: !options.noTimestamp) }
        let imports = parsedFiles.map { FileHeaderHandler.getImports($0, testableFrameworks: options.testableFrameworks) }
        let mocks = parsedFiles.map { Generator(file: $0).generate() }
        
        let mergedFiles = zip(zip(headers, imports), mocks).map { $0.0 + $0.1 + $1 }
        let outputPath = Path(options.output)
        
        do {
            if outputPath.isDirectory {
                let inputPaths = options.files.map { Path($0) }
                for (inputPath, outputText) in zip(inputPaths, mergedFiles) {
                    let fileName = options.filePrefix + inputPath.fileName
                    let outputFile = TextFile(path: outputPath + fileName)
                    try outputText |> outputFile
                }
            } else {
                let outputFile = TextFile(path: outputPath)
                try mergedFiles.joinWithSeparator("\n") |> outputFile
            }
        } catch let error as FileKitError {
            return .Failure(.IOError(error))
        } catch let error {
            return .Failure(.UnknownError(error))
        }
        return .Success()
    }
    
    private func removeClasses(filesRepresentation: [FileRepresentation]) -> [FileRepresentation] {
        return filesRepresentation.map {
                let declarations = $0.declarations.filter { !($0 is ClassDeclaration) }
                return FileRepresentation(sourceFile: $0.sourceFile, declarations: declarations)
            }.filter { !$0.declarations.isEmpty }
    }
    
    public struct Options: OptionsType {
        let files: [String]
        let output: String
        let noHeader: Bool
        let noTimestamp: Bool
        let testableFrameworks: [String]
        let filePrefix: String
        let noClassMocking: Bool
        
        public init(output: String, testableFrameworks: String, noHeader: Bool, noTimestamp: Bool, filePrefix: String, noClassMocking: Bool, files: [String]) {
            self.output = output
            self.testableFrameworks = testableFrameworks.componentsSeparatedByString(",").filter { !$0.isEmpty }
            self.noHeader = noHeader
            self.noTimestamp = noTimestamp
            self.filePrefix = filePrefix
            self.files = files
            self.noClassMocking = noClassMocking
        }
        
        public static func evaluate(m: CommandMode) -> Result<Options, CommandantError<CuckooGeneratorError>> {
            return curry(Options.init)
                <*> m <| Option(key: "output", defaultValue: "GeneratedMocks.swift", usage: "Where to put the generated mocks.\nIf a path to a directory is supplied, each input file will have a respective output file with mocks.\nIf a path to a Swift file is supplied, all mocks will be in a single file.\nDefault value is `GeneratedMocks.swift`.")
                <*> m <| Option(key: "testable", defaultValue: "", usage: "A comma separated list of frameworks that should be imported as @testable in the mock files.")
                <*> m <| Option(key: "no-header", defaultValue: false, usage: "Do not generate file headers.")
                <*> m <| Option(key: "no-timestamp", defaultValue: false, usage: "Do not generate timestamp.")
                <*> m <| Option(key: "file-prefix", defaultValue: "", usage: "Names of generated files in directory will start with this prefix. Only works when output path is directory.")
                <*> m <| Option(key: "no-class-mocking", defaultValue: false, usage: "Do not generate mocks for classes.")
                <*> m <| Argument(usage: "Files to parse and generate mocks for.")
        }
    }
}