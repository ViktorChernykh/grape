import XCTest
@testable import Grape

final class DiskStorageTests: XCTestCase {
	var sut: DiskStorage!
	let decoder = JSONDecoder()
	let encoder = JSONEncoder()

	override func setUp() {
		super.setUp()
		sut = DiskStorage(appKey: "Test")
	}

	override func tearDown() {
		let supportFolderURL = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
		let url = supportFolderURL!
			.appendingPathComponent("Grape")
			.appendingPathComponent("Cache-Test")
			.appendingPathComponent("data")

		if FileManager.default.fileExists(atPath: url.path) {
			do {
				try FileManager.default.removeItem(at: url)
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
		try await sut.write(value)
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
		try await sut.write(value)

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
		try await sut.write(value1)
		try await sut.write(value2)
		try await sut.reduceDataFile()

		let loadedCache: [String : CacheString] = try await sut.loadCache().4
		let cachedModel1: CacheString? = loadedCache[key1]
		let cachedModel2: CacheString? = loadedCache[key2]

		// Then
		XCTAssertNotNil(cachedModel1)
		XCTAssertNil(cachedModel2)
	}

	static var allTests = [
		("test_LoadCache_WhenCacheExists_ReturnCachedModel", test_LoadCache_WhenCacheExists_ReturnCachedModel),
		("test_LoadCache_WhenRemoveCache_ReturnNil", test_LoadCache_WhenRemoveCache_ReturnNil),
		("test_CacheWithExpiredData_WhenReduceDataFile_ReturnOnlyUnexpiredData", test_CacheWithExpiredData_WhenReduceDataFile_ReturnOnlyUnexpiredData),
	]
}
