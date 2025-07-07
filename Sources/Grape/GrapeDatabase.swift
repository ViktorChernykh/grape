//
//  GrapeDatabase.swift
//  Grape
//
//  Created by Victor Chernykh on 14.08.2022.
//

import Foundation
import TraderUserDto

public let grape = GrapeDatabase.shared

public final class GrapeDatabase {
	// MARK: Stored Properties
	public static let shared: GrapeDatabase = .init()

	/// Cache flush Interval in seconds.
	public var memoryFlushInterval: TimeInterval = 1800	// seconds, half hour

	/// Disk storage delegate.
	var storage: StorageProtocol?

	private let storeDate: StoreDate = .init()
	private let storeInt: StoreInt = .init()
	private let storeModel: StoreString = .init()
	private let storePayload: StoreUserPayload = .init()
	private let storeString: StoreString = .init()
	private let storeUUID: StoreUUID = .init()

	private let decoder: JSONDecoder = .init()
	private let encoder: JSONEncoder = .init()
	private var taskFlush: Task<Void, Error>!

	// MARK: - Init
	private init() { }

	// MARK: - Methods
	/// Load the data from cache file.
	/// - Parameter appName: App name for unique folder.
	public func setupStorage(appName: String) async throws {
		storage = DiskStorage(appKey: appName)
		if let data = try await storage?.loadCache() {
			storeDate.setInit(data.0)
			storeInt.setInit(data.1)
			storeString.setInit(data.2)
			storeUUID.setInit(data.3)
			storeModel.setInit(data.4)
		}
		runTaskRemoveExpiredData()
	}

	public func set(memoryFlushInterval: Double) async {
		self.memoryFlushInterval = memoryFlushInterval
	}

	// MARK: - Get methods

	/// Get data from memory cache.
	///
	/// - Parameters:
	///   - key: unique key for search data.
	///   - as: type for decode data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func get<T: Codable>(for key: String, as: T.Type) throws -> T? {
		guard let model: CacheString = storeModel.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}

		guard let data: Data = model.body.data(using: .utf8) else {
			return nil
		}
		return try decoder.decode(T.self, from: data)
	}

	/// Get string from memory cache.
	///
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: String or nil if it not found.
	public func getString(for key: String) -> String? {
		guard let model: CacheString = storeString.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get date from memory cache.
	///
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: Date or nil if it not found.
	public func getDate(for key: String) -> Date? {
		guard let model: CacheDate = storeDate.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get integer from memory cache.
	///
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: Int or nil if it not found.
	public func getInt(for key: String) -> Int? {
		guard let model: CacheInt = storeInt.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get uuid from memory cache.
	///
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: UUID or nil if it not found.
	public func getUUID(for key: String) -> UUID? {
		guard let model: CacheUUID = storeUUID.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get UserPayload from memory cache.
	///
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: UserPayload or nil if it not found.
	public func getPayload(for key: String) -> UserPayload? {
		guard let model: CachePayload = storePayload.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	// MARK: - Set methods

	/// Store an object to memory cache and to disk.
	///
	/// - Parameters:
	///   - model: object for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none .sync .async` .
	public func set<T: Codable>(_ model: T, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let data: Data = try encoder.encode(model)
		let string: String = .init(data: data, encoding: String.Encoding.utf8) ?? ""
		let cacheValue: CacheString = .init(body: string, exp: exp)
		storeModel.set(cacheValue, for: key)
		try await setToDiscStorage(value: string, exp: exp, key: key, policy: policy, type: .model)
	}

	/// Store an string to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: string for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none .sync .async` .
	public func setString(_ value: String, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheString = .init(body: value, exp: exp)
		storeString.set(cacheValue, for: key)
		try await setToDiscStorage(value: value, exp: exp, key: key, policy: policy, type: .string)
	}

	/// Store an date to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: date for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none .sync .async` .
	public func setDate(_ value: Date, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheDate = .init(body: value, exp: exp)
		storeDate.set(cacheValue, for: key)

		let string: String = String(value.timeIntervalSince1970)
		try await setToDiscStorage(value: string, exp: exp, key: key, policy: policy, type: .date)
	}

	/// Store an integer to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: integer for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none .sync .async` .
	public func setInt(_ value: Int, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheInt = .init(body: value, exp: exp)
		storeInt.set(cacheValue, for: key)
		try await setToDiscStorage(value: String(value), exp: exp, key: key, policy: policy, type: .int)
	}

	/// Store an uuid to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: uuid for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none .sync .async` .
	public func setUUID(_ value: UUID, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheUUID = .init(body: value, exp: exp)
		storeUUID.set(cacheValue, for: key)
		try await setToDiscStorage(value: value.uuidString, exp: exp, key: key, policy: policy, type: .uuid)
	}

	/// Store an UserPayload to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: UserPayload for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	public func setPayload(_ value: UserPayload, for key: String, exp: Date? = nil) {
		let cacheValue: CachePayload = .init(body: value, exp: exp)
		storePayload.set(cacheValue, for: key)
	}

	/// Asynchronously saves data to disk storage with specified saving policy.
	///
	/// - Parameters:
	///   - value: The string value to be stored in disk storage.
	///   - exp: Optional expiration date for the cached data.
	///   - key: Unique identifier key for the stored data.
	///   - policy: Saving policy that defines how data should be stored.
	///   - type: Type of cache where the data will be stored.
	///
	/// - Throws: An error if any issue occurs during the saving process.
	private func setToDiscStorage(value: String, exp: Date?, key: String, policy: SavePolicy, type: CacheType) async throws {
		switch policy {
		case .none:
			// No-op when saving policy is set to none
			return
		case .async:
			// Asynchronous saving with medium priority
			Task(priority: .medium) { [weak self] in
				let diskModel: DiskModel = .init(body: value, exp: exp, key: key, type: .uuid)

				// Attempt to write the model to storage
				try await self?.storage?.write(diskModel)
			}
		case .sync:
			// Synchronous saving operation
			let diskModel: DiskModel = .init(body: value, exp: exp, key: key, type: .uuid)

			// Write the model to storage synchronously
			try await storage?.write(diskModel)
		}
	}

	// MARK: - Reset methods

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none .sync .async` .
	public func reset(for key: String, policy: SavePolicy = .none) async throws {
		storeModel.remove(for: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none .sync .async` .
	public func resetDate(for key: String, policy: SavePolicy = .none) async throws {
		storeDate.remove(for: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none .sync .async` .
	public func resetInt(for key: String, policy: SavePolicy = .none) async throws {
		storeInt.remove(for: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none .sync .async` .
	public func resetString(for key: String, policy: SavePolicy = .none) async throws {
		storeString.remove(for: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none .sync .async` .
	public func resetUUID(for key: String, policy: SavePolicy = .none) async throws {
		storeUUID.remove(for: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a UserPayload from the cache by key.
	///
	/// - Parameter key: unique key for data.
	public func resetPayload(for key: String) async throws {
		storePayload.remove(for: key)
		try await resetFromDiscStorage(key, .none)
	}

	/// Deletes all data from the cache.
	public func resetAll() throws {
		storeDate.clear()
		storeInt.clear()
		storeString.clear()
		storeUUID.clear()
		storeModel.clear()
		storePayload.clear()

		try storage?.removeAll()
	}

	/// Removes data from disk storage asynchronously or synchronously based on the specified policy
	///
	/// This method provides functionality to delete stored data from disk storage.
	/// The removal process can be executed either asynchronously or synchronously,
	/// depending on the specified saving policy.
	///
	/// - Parameters:
	///   - key: The unique key of the data to be removed from storage
	///   - policy: The saving policy that determines how the removal operation should be performed
	///
	/// - Throws: An error if any issue occurs during the removal process
	private func resetFromDiscStorage(_ key: String, _ policy: SavePolicy) async throws {
		switch policy {
		case .none:
			return
		case .async:
			Task(priority: .low) { [weak self] in
				try await self?.storage?.removeValue(forKey: key)
			}
		case .sync:
			try await storage?.removeValue(forKey: key)
		}
	}

	// MARK: - Remove methods

	/// Deletes all expired keys.
	private func removeExpiredData() {
		storeDate.removeExpiredData()
		storeInt.removeExpiredData()
		storeModel.removeExpiredData()
		storePayload.removeExpiredData()
		storeString.removeExpiredData()
		storeUUID.removeExpiredData()
	}

	/// Deletes all expired keys.
	private func runTaskRemoveExpiredData() {
		taskFlush = Task(priority: .background) { [weak self] in
			guard let self else {
				return
			}
			while true {
				try await self.storage?.reduceDataFile()
				try await Task.sleep(nanoseconds: UInt64(self.memoryFlushInterval * 1_000_000_000))

				self.removeExpiredData()
				try await Task.sleep(nanoseconds: UInt64(self.memoryFlushInterval * 1_000_000_000))
			}
		}
	}

	deinit {
		taskFlush.cancel()
	}
}
