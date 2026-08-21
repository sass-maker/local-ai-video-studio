import Foundation
import StudioAgentSupport

@main
enum StudioAgentMain {
  static func main() async {
    let service = StudioAgentService()
    var raw: Any?
    do {
      let arguments = CommandLine.arguments
      let data: Data
      if let index = arguments.firstIndex(of: "--request"), arguments.indices.contains(index + 1) {
        data = try Data(contentsOf: URL(filePath: arguments[index + 1]))
      } else {
        data = FileHandle.standardInput.readDataToEndOfFile()
      }
      guard !data.isEmpty else {
        throw StudioAgentError(
          "INVALID_REQUEST", "provide one JSON request on stdin or with --request")
      }
      raw = try JSONSerialization.jsonObject(with: data)
      write(try await service.run(raw as Any))
    } catch {
      write(service.failure(raw, error: error))
      Foundation.exit(1)
    }
  }

  private static func write(_ value: Any) {
    let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
  }
}
