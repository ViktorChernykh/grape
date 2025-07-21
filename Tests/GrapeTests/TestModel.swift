import Foundation

struct TestModel: Codable {
	let name: String
	let age: Int
}

extension TestModel {
	func toJson() -> String {
		let data: Data? = try? JSONEncoder().encode(self)
		guard let data else {
			return ""
		}
		return String(data: data, encoding: String.Encoding.utf8) ?? ""
	}
}
