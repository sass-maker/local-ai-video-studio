import Foundation

public struct StrictDecodingError: Error, Equatable, CustomStringConvertible, Sendable {
    public let path: String
    public let unknownKeys: [String]

    public init(path: String, unknownKeys: [String]) {
        self.path = path
        self.unknownKeys = unknownKeys.sorted()
    }

    public var description: String {
        "Unknown fields at \(path): \(unknownKeys.joined(separator: ", "))"
    }
}

struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension Decoder {
    func rejectUnknownKeys<K: CodingKey>(_ expected: K.Type) throws {
        let all = try container(keyedBy: AnyCodingKey.self).allKeys.map(\.stringValue)
        let allowed = Set(expectedKeys(expected))
        let unknown = all.filter { !allowed.contains($0) }
        guard unknown.isEmpty else {
            let path = codingPath.map(\.stringValue).joined(separator: ".")
            throw StrictDecodingError(path: path.isEmpty ? "$" : path, unknownKeys: unknown)
        }
    }
}

private func expectedKeys<K: CodingKey>(_ type: K.Type) -> [String] {
    // Coding-key enums used by strict models expose their cases through this
    // private protocol. Keeping the list beside each model avoids reflection or
    // accepting arbitrary planner dictionaries.
    (type as? any StrictCodingKey.Type)?.allKeys ?? []
}

protocol StrictCodingKey {
    static var allKeys: [String] { get }
}
