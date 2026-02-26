import Foundation

enum PythonRunner {
    static func run(scriptURL: URL, args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["python3", scriptURL.path] + args

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        try p.run()
        p.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""

        if p.terminationStatus != 0 {
            throw NSError(domain: "PythonRunner", code: Int(p.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: err.isEmpty ? "Python failed" : err
            ])
        }

        return out
    }
}
