import XCTest
@testable import Grape

final class GrapeDatabaseTests: XCTestCase {
	var sut: GrapeDatabase!

	override func setUp() {
		super.setUp()
		sut = GrapeDatabase.shared
	}

	override func tearDownWithError() throws {
		let supportFolderURL = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

		let url = supportFolderURL!
			.appendingPathComponent("Grape")
			.appendingPathComponent("Cache-Test")
			.appendingPathComponent("data")

		if FileManager.default.fileExists(atPath: url.path) {
			try FileManager.default.removeItem(at: url)
		}
		try super.tearDownWithError()
	}

	func test_SetUpGrapeDatabase_WhenSetup_ShouldSetNewProperties() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")

		// When
		await sut.set(memoryFlushInterval: 8)

		let memoryFlushInterval1 = sut.memoryFlushInterval
		let isDiskStorage = sut.storage is DiskStorage

		// Then
		XCTAssertEqual(memoryFlushInterval1, 8, "Memory flush interval1 should match 8")
		XCTAssertTrue(isDiskStorage, "Type of `database.storage` should match the DiskStorage")

		// When 2
		await sut.set(memoryFlushInterval: 10)
		let memoryFlushInterval2 = sut.memoryFlushInterval

		// Then 2
		XCTAssertEqual(memoryFlushInterval2, 10, "Memory flush interval1 should match 10")
	}

	func test_GetCache_WhenKeyExists_ReturnValue() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key = "testKey"
		let value = TestModel(name: "Name", age: 30)
		try await sut.set(value, for: key, policy: .sync)

		// When
		let model = try sut.get(for: key, as: TestModel.self)

		// Then
		XCTAssertEqual(model?.name, value.name, "Retrieved name should match the original name")
		XCTAssertEqual(model?.age, value.age, "Retrieved age should match the original age")
	}

	func test_GetString_WhenKeyExists_ReturnValue() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key = "testKey"
		let value = "Name"
		try await sut.setString(value, for: key, policy: .sync)

		// When
		let cache: String? = sut.getString(for: key)

		// Then
		XCTAssertEqual(cache ?? "", value, "Retrieved name should match the original name")
	}

	func test_GetCache_WhenKeyNotExists_ReturnNil() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key = "testKey"
		let value = "testValue"
		try await sut.set(value, for: key)

		// When
		let retrievedValue = try sut.get(for: key + "1", as: String.self)

		// Then
		XCTAssertNil(retrievedValue, "Retrieved value should match the nil")
	}

	func test_GetCache_WhenCacheExpiration_ReturnNil() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key = "testKey"
		let value = "testValue"
		let expirationDate = Date(timeIntervalSinceNow: 1)

		// When
		try await sut.set(value, for: key, exp: expirationDate)
		let retrievedValue = try sut.get(for: key, as: String.self)

		// Then
		XCTAssertEqual(retrievedValue, value, "Retrieved value should match the original value before expiration")

		sleep(2) // Sleep for 2 seconds to wait for the expiration
		let expiredValue = try sut.get(for: key, as: String.self)
		XCTAssertNil(expiredValue, "Retrieved value should be nil after expiration")
	}

	func test_GetCache_WhenCacheReset_ReturnNil() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key = "testKey"
		let value = "testValue"

		// When
		try await sut.set(value, for: key)
		try await sut.reset(for: key)

		let retrievedValue = try sut.get(for: key, as: String.self)

		// Then
		XCTAssertNil(retrievedValue, "Retrieved value should be nil after resetting the cache")
	}

	func test_RemoveExpiredData_WhenDataHasExpired_CacheMustBeDeleted() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		await sut.set(memoryFlushInterval: 1.5)
		let key = "testKey"
		let value = "testValue"
		let expirationDate = Date(timeIntervalSinceNow: 1)

		// When
		try await sut.set(value, for: key, exp: expirationDate)

		let retrievedValue1 = try sut.get(for: key, as: String.self)

		// Then
		XCTAssertEqual(retrievedValue1, value, "Retrieved value should match the original value before flushing cache")

		// Sleep for the memory flush interval to trigger cache removal
		sleep(2)
		let retrievedValue2 = try sut.get(for: key, as: String.self)
		XCTAssertNil(retrievedValue2, "Retrieved value should be nil after flushing cache")
	}

	static var allTests = [
		("test_SetUpGrapeDatabase_WhenSetup_ShouldSetNewProperties", test_SetUpGrapeDatabase_WhenSetup_ShouldSetNewProperties),
		("test_GetCache_WhenKeyExists_ReturnValue", test_GetCache_WhenKeyExists_ReturnValue),
		("test_GetString_WhenKeyExists_ReturnValue", test_GetString_WhenKeyExists_ReturnValue),
		("test_GetCache_WhenKeyNotExists_ReturnNil", test_GetCache_WhenKeyNotExists_ReturnNil),
		("test_GetCache_WhenCacheExpiration_ReturnNil", test_GetCache_WhenCacheExpiration_ReturnNil),
		("test_GetCache_WhenCacheReset_ReturnNil", test_GetCache_WhenCacheReset_ReturnNil),
		("test_RemoveExpiredData_WhenDataHasExpired_CacheMustBeDeleted", test_RemoveExpiredData_WhenDataHasExpired_CacheMustBeDeleted),
	]
}
