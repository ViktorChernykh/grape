import TraderUserDto
import XCTest
@testable import Grape

final class DiskStorageTests: XCTestCase {
	var sut: DiskStorage!
	let decoder: JSONDecoder = .init()
	let encoder: JSONEncoder = .init()

	override func setUp() {
		super.setUp()
		sut = DiskStorage(appKey: "Test")
	}

	override func tearDown() {
		let supportFolderURL: URL? = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

		let url: URL = supportFolderURL!
			.appendingPathComponent("Grape")
			.appendingPathComponent("Cache-Test")
			.appendingPathComponent("data")

		if FileManager.default.fileExists(atPath: url.path) {
			do {
				let handle: FileHandle = try .init(forWritingTo: url)
				try handle.truncate(atOffset: 0)
			} catch {
				print(error.localizedDescription)
			}
		}
		super.tearDown()
	}

	func test_LoadCache_WhenCacheExists_ReturnCachedModel() async throws {
		// Given
		let key: String = "testKey"
		let exp: Date = .init(timeIntervalSinceNow: 600)
		let model: TestModel = .init(name: "Victor", age: 20)
		let string: String = model.toJson()
		let value: DiskModel = .init(body: string, exp: exp, key: key, type: .model)

		// When
		try sut.write(value)
		let cache: [String : CacheString] = try await sut.loadCache().4
		let cachedModel: CacheString? = cache[key]
		let data: Data = cachedModel?.body.data(using: .utf8) ?? Data()
		let retrievedModel: TestModel = try decoder.decode(TestModel.self, from: data)

		// Then
		XCTAssertNotNil(cachedModel)
		XCTAssertEqual(retrievedModel.name, model.name)
		XCTAssertEqual(retrievedModel.age, model.age)
		XCTAssertEqual(cachedModel?.exp, exp)
	}

	func test_LoadCache_WhenRemoveCache_ReturnNil() async throws {
		// Given
		let model: TestModel = .init(name: "Victor", age: 20)
		let key: String = "testKey"
		let exp: Date = .init(timeIntervalSinceNow: 60)
		let string: String = model.toJson()
		let value: DiskModel = .init(body: string, exp: exp, key: key, type: .model)
		try sut.write(value)

		// When
		try await sut.removeValue(forKey: key)
		let cache: [String : CacheString] = try await sut.loadCache().4
		let cachedModel: CacheString? = cache[key]

		// Then
		XCTAssertNil(cachedModel)
	}

	func test_CacheWithExpiredData_WhenReduceDataFile_ReturnOnlyUnexpiredData() async throws {
		// Given
		let model1: TestModel = .init(name: "Victor", age: 20)
		let key1: String = "TestKey1"
		let exp1: Date = .init(timeIntervalSinceNow: 60) // Expires in 60 seconds
		let string1: String = model1.toJson()
		let value1: DiskModel = .init(body: string1, exp: exp1, key: key1, type: .model)

		let model2: TestModel = .init(name: "Mike", age: 30)
		let key2: String = "TestKey2"
		let exp2: Date = .init(timeIntervalSinceNow: -60) // Expired 60 seconds ago
		let string2: String = model2.toJson()
		let value2: DiskModel = .init(body: string2, exp: exp2, key: key2, type: .model)

		// When
		try sut.write(value1)
		try sut.write(value2)
		try await sut.reduceDataFile()

		let loadedCache: [String : CacheString] = try await sut.loadCache().4
		let cachedModel1: CacheString? = loadedCache[key1]
		let cachedModel2: CacheString? = loadedCache[key2]

		// Then
		XCTAssertNotNil(cachedModel1)
		XCTAssertNil(cachedModel2)
	}

	func test_LoadPayload_WhenCacheExists_ReturnUserPayload() async throws {
		// Given
		let key: String = "testKey"
		let exp: Date = .init(timeIntervalSinceNow: 600)
		let userId: UUID = .init()

		let payload: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let data1: Data = try encoder.encode(payload)
		let string: String = .init(data: data1, encoding: String.Encoding.utf8) ?? ""
		let diskModel: DiskModel = .init(body: string, exp: exp, key: key, type: .payload)

		// When
		try sut.write(diskModel)
		let cache: [String: CachePayload] = try await sut.loadCache().5
		let cachedPayload: CachePayload? = cache[key]

		// Then
		let model: CachePayload = try XCTUnwrap(cachedPayload)

		XCTAssertEqual(model.body.jti, payload.jti)
		XCTAssertEqual(model.body.firstName, payload.firstName)
		XCTAssertEqual(model.exp, exp)
	}

	static let allTests = [
		("test_LoadCache_WhenCacheExists_ReturnCachedModel", test_LoadCache_WhenCacheExists_ReturnCachedModel),
		("test_LoadCache_WhenRemoveCache_ReturnNil", test_LoadCache_WhenRemoveCache_ReturnNil),
		("test_CacheWithExpiredData_WhenReduceDataFile_ReturnOnlyUnexpiredData", test_CacheWithExpiredData_WhenReduceDataFile_ReturnOnlyUnexpiredData),
		("test_LoadPayload_WhenCacheExists_ReturnUserPayload", test_LoadPayload_WhenCacheExists_ReturnUserPayload),
	]
}
