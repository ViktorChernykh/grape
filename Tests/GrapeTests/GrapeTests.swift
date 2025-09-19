import TraderUserDto
import XCTest
@testable import Grape

final class GrapeDatabaseTests: XCTestCase {
	var sut: GrapeDatabase!

	override func setUp() {
		super.setUp()
		sut = GrapeDatabase.shared
	}

	override func tearDownWithError() throws {
		let supportFolderURL: URL? = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

		let url: URL = supportFolderURL!
			.appendingPathComponent("Grape")
			.appendingPathComponent("Cache-Test")
			.appendingPathComponent("data")

		if FileManager.default.fileExists(atPath: url.path) {
			let handle: FileHandle = try .init(forWritingTo: url)
			try handle.truncate(atOffset: 0)
		}
		try super.tearDownWithError()
	}

	func test_SetUpGrapeDatabase_WhenSetup_ShouldSetNewProperties() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")

		// When
		sut.set(memoryFlushInterval: 8)

		let memoryFlushInterval1: TimeInterval = sut.getMemoryFlushInterval()

		// Then
		XCTAssertEqual(memoryFlushInterval1, 8, "Memory flush interval1 should match 8")

		// When 2
		sut.set(memoryFlushInterval: 10)
		let memoryFlushInterval2: TimeInterval = sut.getMemoryFlushInterval()

		// Then 2
		XCTAssertEqual(memoryFlushInterval2, 10, "Memory flush interval1 should match 10")
	}

	func test_GetCache_WhenKeyExists_ReturnValue() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key: String = "testKey"
		let value: TestModel = .init(name: "Name", age: 30)
		try sut.set(value, for: key, save: .sync)

		// When
		let model: TestModel? = try sut.get(for: key, as: TestModel.self)

		// Then
		XCTAssertEqual(model?.name, value.name, "Retrieved name should match the original name")
		XCTAssertEqual(model?.age, value.age, "Retrieved age should match the original age")
	}

	func test_GetString_WhenKeyExists_ReturnValue() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key: String = "testKey"
		let value: String = "Name"
		try sut.setString(value, for: key, save: .sync)

		// When
		let cache: String? = sut.getString(for: key)

		// Then
		XCTAssertEqual(cache ?? "", value, "Retrieved name should match the original name")
	}

	func test_GetCache_WhenKeyNotExists_ReturnNil() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key: String = "testKey"
		let value: String = "testValue"
		try sut.set(value, for: key, save: .none)

		// When
		let retrievedValue: String? = try sut.get(for: key + "1", as: String.self)

		// Then
		XCTAssertNil(retrievedValue, "Retrieved value should match the nil")
	}

	func test_GetCache_WhenCacheExpiration_ReturnNil() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key: String = "testKey"
		let value: String = "testValue"
		let expirationDate: Date = .init(timeIntervalSinceNow: 1)

		// When
		try sut.set(value, for: key, exp: expirationDate, save: .none)
		let retrievedValue = try sut.get(for: key, as: String.self)

		// Then
		XCTAssertEqual(retrievedValue, value, "Retrieved value should match the original value before expiration")

		sleep(2) // Sleep for 2 seconds to wait for the expiration
		let expiredValue: String? = try sut.get(for: key, as: String.self)
		XCTAssertNil(expiredValue, "Retrieved value should be nil after expiration")
	}

	func test_GetCache_WhenCacheReset_ReturnNil() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key: String = "testKey"
		let value: String = "testValue"

		// When
		try sut.set(value, for: key, save: .none)
		try sut.reset(for: key, save: .none)

		let retrievedValue: String? = try sut.get(for: key, as: String.self)

		// Then
		XCTAssertNil(retrievedValue, "Retrieved value should be nil after resetting the cache")
	}

	func test_RemoveExpiredData_WhenDataHasExpired_CacheMustBeDeleted() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		sut.set(memoryFlushInterval: 1.5)
		let key: String = "testKey"
		let value: String = "testValue"
		let expirationDate: Date = .init(timeIntervalSinceNow: 1)

		// When
		try sut.set(value, for: key, exp: expirationDate, save: .none)

		let retrievedValue1: String? = try sut.get(for: key, as: String.self)

		// Then
		XCTAssertEqual(retrievedValue1, value, "Retrieved value should match the original value before flushing cache")

		// Sleep for the memory flush interval to trigger cache removal
		sleep(2)
		let retrievedValue2: String? = try sut.get(for: key, as: String.self)
		XCTAssertNil(retrievedValue2, "Retrieved value should be nil after flushing cache")
	}

	func test_GetUserPayload_WhenKeyExists_ReturnValue() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")
		let key: String = "testKey"
		let value: UserPayload = .init(
			jti: UUID(),
			sub: UUID(),
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let expirationDate: Date = .init(timeIntervalSinceNow: 1)

		// When
		try sut.setPayload(value, for: key, exp: expirationDate, save: .sync)
		let val = sut.getPayload(for: key)
		let payload: UserPayload = try XCTUnwrap(val)

		// Then
		XCTAssertEqual(value.jti, payload.jti, "Retrieved value should match the original value before expiration")

		sleep(2) // Sleep for 2 seconds to wait for the expiration
		let expiredValue: UserPayload? = sut.getPayload(for: key)
		XCTAssertNil(expiredValue, "Retrieved value should be nil after expiration")
	}

	func test_GetPayloads_ForUserId_ReturnValues() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")

		let key1: String = "testKey1"
		let key2: String = "testKey2"
		let key3: String = "testKey3"
		let userId: UUID = .init()

		let value1: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let value2: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let value3: UserPayload = .init(
			jti: UUID(),
			sub: UUID(),
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let expirationDate: Date = .init(timeIntervalSinceNow: 1)

		// When
		try sut.setPayload(value1, for: key1, exp: expirationDate, save: .sync)
		try sut.setPayload(value2, for: key2, exp: expirationDate, save: .sync)
		try sut.setPayload(value3, for: key3, exp: expirationDate, save: .sync)
		var values: [UserPayload] = sut.getPayloads(with: userId)

		// Then
		XCTAssertEqual(values.count, 2, "Retrieved 2 values")

		sleep(2) // Sleep for 2 seconds to wait for the expiration
		values = sut.getPayloads(with: userId)
		XCTAssert(values.isEmpty, "Retrieved value should be empty")
	}

	func test_UpdateRoleType_ForUserId_UpdateValues() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")

		let key1: String = "testKey1"
		let key2: String = "testKey2"
		let userId: UUID = .init()

		let value1: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let value2: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)

		let expirationDate: Date = .init(timeIntervalSinceNow: 2)
		try sut.setPayload(value1, for: key1, exp: expirationDate, save: .sync)
		try sut.setPayload(value2, for: key2, exp: expirationDate, save: .sync)

		// When
		try sut.updatePayload(role: 1, for: userId, save: .sync)
		let values: [UserPayload] = sut.getPayloads(with: userId)

		// Then
		XCTAssertEqual(values[0].roleLevel, 1)
		XCTAssertEqual(values[1].roleLevel, 1)
	}

	func test_DeletePayloads_ForUserId_DeleteValues() async throws {
		// Given
		try await sut.setupStorage(appName: "Test")

		let key1: String = "testKey1"
		let key2: String = "testKey2"
		let key3: String = "testKey3"
		let userId: UUID = .init()

		let value1: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let value2: UserPayload = .init(
			jti: UUID(),
			sub: userId,
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let value3: UserPayload = .init(
			jti: UUID(),
			sub: UUID(),
			firstName: "Victor",
			lang: .en,
			roleLevel: 0,
			tariff: .starter,
			ip: ""
		)
		let expirationDate: Date = .init(timeIntervalSinceNow: 2)

		// When
		try sut.setPayload(value1, for: key1, exp: expirationDate, save: .sync)
		try sut.setPayload(value2, for: key2, exp: expirationDate, save: .sync)
		try sut.setPayload(value3, for: key3, exp: expirationDate, save: .sync)

		// Then
		var values: [UserPayload] = sut.getPayloads(with: userId)
		XCTAssertEqual(values.count, 2)
		try sut.resetPayload(for: userId, save: .sync)
		values = sut.getPayloads(with: userId)
		XCTAssertEqual(values.count, 0)
	}

	static let allTests = [
		("test_SetUpGrapeDatabase_WhenSetup_ShouldSetNewProperties", test_SetUpGrapeDatabase_WhenSetup_ShouldSetNewProperties),
		("test_GetCache_WhenKeyExists_ReturnValue", test_GetCache_WhenKeyExists_ReturnValue),
		("test_GetString_WhenKeyExists_ReturnValue", test_GetString_WhenKeyExists_ReturnValue),
		("test_GetCache_WhenKeyNotExists_ReturnNil", test_GetCache_WhenKeyNotExists_ReturnNil),
		("test_GetCache_WhenCacheExpiration_ReturnNil", test_GetCache_WhenCacheExpiration_ReturnNil),
		("test_GetCache_WhenCacheReset_ReturnNil", test_GetCache_WhenCacheReset_ReturnNil),
		("test_RemoveExpiredData_WhenDataHasExpired_CacheMustBeDeleted", test_RemoveExpiredData_WhenDataHasExpired_CacheMustBeDeleted),
		("test_GetUserPayload_WhenKeyExists_ReturnValue", test_GetUserPayload_WhenKeyExists_ReturnValue),
		("test_GetPayloads_ForUserId_ReturnValues", test_GetPayloads_ForUserId_ReturnValues),
		("test_UpdateRoleType_ForUserId_UpdateValues", test_UpdateRoleType_ForUserId_UpdateValues),
		("test_DeletePayloads_ForUserId_DeleteValues", test_DeletePayloads_ForUserId_DeleteValues),
	]
}
