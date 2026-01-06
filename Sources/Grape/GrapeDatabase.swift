//
//  GrapeDatabase.swift
//  Grape
//
//  Created by Victor Chernykh on 14.08.2022.
//

import Foundation
import TraderUserDto

public final class GrapeDatabase: Sendable {
	// MARK: Stored Properties
	public static let shared: GrapeDatabase = .init()

	private let dateStorage: DateStorage = .init()
	private let intStorage: IntStorage = .init()
	private let modelStorage: StringStorage = .init()
	private let payloadStorage: UserPayloadStorage = .init()
	private let stringStorage: StringStorage = .init()
	private let UUIDStorage: UUIDStorage = .init()
	private let timeIntervalStorage: TimeIntervalStorage = .init()

	private let decoder: JSONDecoder = .init()
	private let encoder: JSONEncoder = .init()

	/// Disk storage delegate.
	nonisolated(unsafe)
	private var storage: (any StorageProtocol)?

	nonisolated(unsafe)
	private var taskFlush: Task<Void, any Error>?

	// MARK: - Init
	private init() { }

	// MARK: - Methods
	/// Load the data from cache file.
	/// - Parameter appName: App name for unique folder.
	public func setupStorage(appName: String) async throws {
		guard storage == nil else {
			return
		}
		storage = DiskStorage(appKey: appName)
		if let data = try await storage?.loadCache() {
			dateStorage.setInit(data.0)
			intStorage.setInit(data.1)
			stringStorage.setInit(data.2)
			UUIDStorage.setInit(data.3)
			modelStorage.setInit(data.4)
		}
		runTaskRemoveExpiredData()
	}

	public func getMemoryFlushInterval() -> TimeInterval {
		timeIntervalStorage.get()
	}

	public func set(memoryFlushInterval: Double) {
		timeIntervalStorage.set(memoryFlushInterval)
	}

	// MARK: - Get methods

	/// Gets a data from memory cache.
	///
	/// - Parameters:
	///   - key: Unique key for search data.
	///   - type: Type for decode data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func get<T: Codable>(for key: String, as type: T.Type) throws -> T? {
		guard let model: CacheString = modelStorage.get(for: key) else {
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

	/// Gets a string from memory cache.
	///
	/// - Parameters:
	///   - key: Unique key for search data.
	/// - Returns: String or nil if it not found.
	public func getString(for key: String) -> String? {
		guard let model: CacheString = stringStorage.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			return nil	// The data has expired
		}
		return model.body
	}

	/// Gets a date from memory cache.
	///
	/// - Parameters:
	///   - key: Unique key for search data.
	/// - Returns: Date or nil if it not found.
	public func getDate(for key: String) -> Date? {
		guard let model: CacheDate = dateStorage.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			return nil	// The data has expired
		}
		return model.body
	}

	/// Gets an integer from memory cache.
	///
	/// - Parameters:
	///   - key: Unique key for search data.
	/// - Returns: Int or nil if it not found.
	public func getInt(for key: String) -> Int? {
		guard let model: CacheInt = intStorage.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			return nil	// The data has expired
		}
		return model.body
	}

	/// Gets a uuid from memory cache.
	///
	/// - Parameters:
	///   - key: Unique key for search data.
	/// - Returns: UUID or nil if it not found.
	public func getUUID(for key: String) -> UUID? {
		guard let model: CacheUUID = UUIDStorage.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			return nil	// The data has expired
		}
		return model.body
	}

	/// Gets a UserPayload from memory cache.
	///
	/// - Parameters:
	///   - key: Unique key for search data.
	/// - Returns: UserPayload or nil if it not found.
	public func getPayload(for key: String) -> UserPayload? {
		guard let model: CachePayload = payloadStorage.get(for: key) else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			return nil	// The data has expired
		}
		return model.body
	}

	/// Gets UserPayloads from memory cache for user ID.
	///
	/// - Parameter userId: User ID for filter.
	/// - Returns: Array of UserPayloads with specified user ID.
	public func getPayloads(with userId: UUID) -> [UserPayload] {
		payloadStorage.get(for: userId)
	}

	// MARK: - Set methods

	/// Store an object to memory cache and to disk.
	///
	/// - Parameters:
	///   - model: Object for save.
	///   - key: Unique key for search data.
	///   - exp: Expiration date.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func set<T: Codable>(_ model: T, for key: String, exp: Date? = nil, save policy: SavePolicy) throws {
		let data: Data = try encoder.encode(model)
		let string: String = .init(data: data, encoding: String.Encoding.utf8) ?? ""
		let cacheValue: CacheString = .init(body: string, exp: exp)
		modelStorage.set(cacheValue, for: key)
		if policy != .none {
			try setToDiscStorage(value: string, exp: exp, key: key, save: policy, type: .model)
		}
	}

	/// Store a string to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: String for save.
	///   - key: Unique key for search data.
	///   - exp: Expiration date.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func setString(_ value: String, for key: String, exp: Date? = nil, save policy: SavePolicy) throws {
		let cacheValue: CacheString = .init(body: value, exp: exp)
		stringStorage.set(cacheValue, for: key)
		if policy != .none {
			try setToDiscStorage(value: value, exp: exp, key: key, save: policy, type: .string)
		}
	}

	/// Store a date to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: Date for save.
	///   - key: Unique key for search data.
	///   - exp: Expiration date.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func setDate(_ value: Date, for key: String, exp: Date? = nil, save policy: SavePolicy) throws {
		let cacheValue: CacheDate = .init(body: value, exp: exp)
		dateStorage.set(cacheValue, for: key)
		let string: String = String(value.timeIntervalSince1970)
		if policy != .none {
			try setToDiscStorage(value: string, exp: exp, key: key, save: policy, type: .date)
		}
	}

	/// Store an integer to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: Integer for save.
	///   - key: Unique key for search data.
	///   - exp: Expiration date.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func setInt(_ value: Int, for key: String, exp: Date? = nil, save policy: SavePolicy) throws {
		let cacheValue: CacheInt = .init(body: value, exp: exp)
		intStorage.set(cacheValue, for: key)
		if policy != .none {
			try setToDiscStorage(value: String(value), exp: exp, key: key, save: policy, type: .int)
		}
	}

	/// Store a uuid to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: UUID for save.
	///   - key: Unique key for search data.
	///   - exp: Expiration date.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func setUUID(_ value: UUID, for key: String, exp: Date? = nil, save policy: SavePolicy) throws {
		let cacheValue: CacheUUID = .init(body: value, exp: exp)
		UUIDStorage.set(cacheValue, for: key)
		if policy != .none {
			try setToDiscStorage(value: value.uuidString, exp: exp, key: key, save: policy, type: .uuid)
		}
	}

	/// Store a UserPayload to memory cache and to disk.
	///
	/// - Parameters:
	///   - value: UserPayload for save.
	///   - key: Unique key for search data.
	///   - exp: Expiration date.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func setPayload(_ value: UserPayload, for key: String, exp: Date? = nil, save policy: SavePolicy) throws {
		let cacheValue: CachePayload = .init(body: value, exp: exp)
		payloadStorage.set(cacheValue, for: key)

		let data: Data = try encoder.encode(value)
		let string: String = .init(data: data, encoding: String.Encoding.utf8) ?? ""
		if policy != .none {
			try setToDiscStorage(value: string, exp: exp, key: key, save: policy, type: .payload)
		}
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
	private func setToDiscStorage(value: String, exp: Date?, key: String, save policy: SavePolicy, type: CacheType) throws {
		switch policy {
		case .none:
			// No-op when saving policy is set to none
			return
		case .async:
			// Asynchronous saving with medium priority
			Task(priority: .medium) { [weak self] in
				let diskModel: DiskModel = .init(body: value, exp: exp, key: key, type: type)

				// Attempt to write the model to storage
				try self?.storage?.write(diskModel)
			}
		case .sync:
			// Synchronous saving operation
			let diskModel: DiskModel = .init(body: value, exp: exp, key: key, type: type)

			// Write the model to storage synchronously
			try storage?.write(diskModel)
		}
	}

	// MARK: - Reset methods

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func reset(for key: String, save policy: SavePolicy) throws {
		modelStorage.remove(for: key)
		try resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func resetDate(for key: String, save policy: SavePolicy) throws {
		dateStorage.remove(for: key)
		try resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func resetInt(for key: String, save policy: SavePolicy) throws {
		intStorage.remove(for: key)
		try resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func resetString(for key: String, save policy: SavePolicy) throws {
		stringStorage.remove(for: key)
		try resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func resetUUID(for key: String, save policy: SavePolicy) throws {
		UUIDStorage.remove(for: key)
		try resetFromDiscStorage(key, policy)
	}

	/// Deletes a UserPayload from the cache by key.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func resetPayload(for key: String, save policy: SavePolicy) throws {
		payloadStorage.remove(for: key)
		try resetFromDiscStorage(key, policy)
	}

	/// Deletes a UserPayload from the cache by userId.
	///
	/// - Parameters:
	///   - key: Unique key for data.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func resetPayload(for userId: UUID, save policy: SavePolicy) throws {
		let keys: [String] = payloadStorage.remove(for: userId)
		for key in keys {
			try resetFromDiscStorage(key, policy)
		}
	}

	/// Update roleLevel for user ID.
	///
	/// - Parameters:
	///   - role: User role type.
	///   - userId: User id.
	///   - policy: Disk save policy: `.none .sync .async` .
	public func updatePayload(role: Int16, for userId: UUID, save policy: SavePolicy) throws {
		let caches: [String: CachePayload] = payloadStorage.update(role: role, for: userId)
		for (key, cache) in caches {
			try resetFromDiscStorage(key, policy)

			let data: Data = try encoder.encode(cache)
			let string: String = .init(data: data, encoding: String.Encoding.utf8) ?? ""
			try setToDiscStorage(value: string, exp: cache.exp, key: key, save: policy, type: .payload)
		}
	}

	/// Deletes all data from the cache.
	public func resetAll() throws {
		dateStorage.clear()
		intStorage.clear()
		stringStorage.clear()
		UUIDStorage.clear()
		modelStorage.clear()
		payloadStorage.clear()

		try storage?.removeAll()
	}

	/// Removes data from disk storage asynchronously or synchronously based on the specified policy
	///
	/// The removal process can be executed either asynchronously or synchronously,
	/// depending on the specified saving policy.
	///
	/// - Parameters:
	///   - key: The unique key of the data to be removed from storage
	///   - policy: The saving policy that determines how the removal operation should be performed
	///
	/// - Throws: An error if any issue occurs during the removal process
	private func resetFromDiscStorage(_ key: String, _ policy: SavePolicy) throws {
		switch policy {
		case .none:
			return
		case .async:
			Task(priority: .low) { [weak self] in
				try await self?.storage?.removeValue(forKey: key)
			}
		case .sync:
			Task(priority: .high) { [weak self] in
				try await self?.storage?.removeValue(forKey: key)
			}
		}
	}

	// MARK: - Remove methods

	/// Deletes all expired keys.
	private func removeExpiredData() {
		dateStorage.removeExpiredData()
		intStorage.removeExpiredData()
		modelStorage.removeExpiredData()
		payloadStorage.removeExpiredData()
		stringStorage.removeExpiredData()
		UUIDStorage.removeExpiredData()
	}

	/// Deletes all expired keys.
	private func runTaskRemoveExpiredData() {
		taskFlush = Task(priority: .background) { [weak self] in
			guard let self else {
				return
			}
			while true {
				try await self.storage?.reduceDataFile()
				try await Task.sleep(for: .seconds(self.getMemoryFlushInterval()))
				guard let task = self.taskFlush, !task.isCancelled else {
					break
				}

				self.removeExpiredData()
				try await Task.sleep(for: .seconds(self.getMemoryFlushInterval()))
				guard let task = self.taskFlush, !task.isCancelled else {
					break
				}
			}
		}
	}

	deinit {
		taskFlush?.cancel()
		taskFlush = nil
	}
}
