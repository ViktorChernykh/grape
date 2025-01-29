//
//  GrapeDatabase.swift
//  Grape
//
//  Created by Victor Chernykh on 14.08.2022.
//

import Foundation
import TraderUserDto

public let grape = GrapeDatabase.shared

public actor GrapeDatabase {
	// MARK: Stored Properties
	public static var shared: GrapeDatabase = .init()

	/// Cache flush Interval in seconds.
	public var memoryFlushInterval: TimeInterval = 1800	// seconds, half hour

	/// Disk storage delegate.
	var storage: StorageProtocol?

	private var cache: [String: CacheString] = [:]
	private var cacheDate: [String: CacheDate] = [:]
	private var cacheInt: [String: CacheInt] = [:]
	private var cacheString: [String: CacheString] = [:]
	private var cacheUUID: [String: CacheUUID] = [:]
	private var cachePayload: [String: CachePayload] = [:]

	private let decoder: JSONDecoder = .init()
	private let encoder: JSONEncoder = .init()
	private let formatter: DateFormatter = .init()
	private var taskFlush: Task<Void, Error>!

	// MARK: - Init
	private init() {
		Task {
			await removeExpiredData()
		}
	}

	// MARK: - Methods
	/// Load the data from cache file.
	/// - Parameter appKey: App name for unique folder.
	public func setupStorage(appName: String) async throws {
		storage = DiskStorage(appKey: appName)
		if let data = try await storage?.loadCache() {
			cacheDate = data.0
			cacheInt = data.1
			cacheString = data.2
			cacheUUID = data.3
			cache = data.4
		}
	}

	public func set(memoryFlushInterval: Double) async {
		self.memoryFlushInterval = memoryFlushInterval
	}

	// MARK: - Get methods

	/// Get data from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	///   - as: type for decode data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func get<T: Codable>(by key: String, as: T.Type) throws -> T? {
		guard let model: CacheString = cache[key] else {
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
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: String or nil if it not found.
	public func getString(by key: String) -> String? {
		guard let model: CacheString = cacheString[key] else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get date from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: Date or nil if it not found.
	public func getDate(by key: String) -> Date? {
		guard let model: CacheDate = cacheDate[key] else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get integer from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: Int or nil if it not found.
	public func getInt(by key: String) -> Int? {
		guard let model: CacheInt = cacheInt[key] else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get uuid from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: UUID or nil if it not found.
	public func getUUID(by key: String) -> UUID? {
		guard let model: CacheUUID = cacheUUID[key] else {
			return nil
		}
		if let exp: Date = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model.body
	}

	/// Get UserPayload from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: UserPayload or nil if it not found.
	public func getPayload(by key: String) -> UserPayload? {
		guard let model: CachePayload = cachePayload[key] else {
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
	/// - Parameters:
	///   - model: object for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func set<T: Codable>(_ model: T, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let data: Data = try encoder.encode(model)
		let string: String = .init(data: data, encoding: String.Encoding.utf8) ?? ""
		let cacheValue: CacheString = .init(body: string, exp: exp)
		cache[key] = cacheValue
		try await setToDiscStorage(value: string, exp: exp, key: key, policy: policy, type: .model)
	}

	/// Store an string to memory cache and to disk.
	/// - Parameters:
	///   - value: string for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func setString(_ value: String, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheString = .init(body: value, exp: exp)
		cacheString[key] = cacheValue
		try await setToDiscStorage(value: value, exp: exp, key: key, policy: policy, type: .string)
	}

	/// Store an date to memory cache and to disk.
	/// - Parameters:
	///   - value: date for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func setDate(_ value: Date, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheDate = .init(body: value, exp: exp)
		cacheDate[key] = cacheValue

		let string = formatter.string(from: value)
		try await setToDiscStorage(value: string, exp: exp, key: key, policy: policy, type: .date)
	}

	/// Store an integer to memory cache and to disk.
	/// - Parameters:
	///   - value: integer for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func setInt(_ value: Int, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheInt = .init(body: value, exp: exp)
		cacheInt[key] = cacheValue
		try await setToDiscStorage(value: String(value), exp: exp, key: key, policy: policy, type: .int)
	}

	/// Store an uuid to memory cache and to disk.
	/// - Parameters:
	///   - value: uuid for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func setUUID(_ value: UUID, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let cacheValue: CacheUUID = .init(body: value, exp: exp)
		cacheUUID[key] = cacheValue
		try await setToDiscStorage(value: value.uuidString, exp: exp, key: key, policy: policy, type: .uuid)
	}

	/// Store an UserPayload to memory cache and to disk.
	/// - Parameters:
	///   - value: UserPayload for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	public func setPayload(_ value: UserPayload, for key: String, exp: Date? = nil) {
		let cacheValue: CachePayload = .init(body: value, exp: exp)
		cachePayload[key] = cacheValue
	}

	private func setToDiscStorage(value: String, exp: Date?, key: String, policy: SavePolicy, type: CacheType) async throws {
		switch policy {
		case .none:
			return
		case .async:
			Task(priority: .medium) { [weak self] in
				let diskModel: DiskModel = .init(body: value, exp: exp, key: key, type: .uuid)
				try await self?.storage?.write(diskModel)
			}
		case .sync:
			let diskModel = DiskModel(body: value, exp: exp, key: key, type: .uuid)
			try await storage?.write(diskModel)
		}
	}

	// MARK: - Reset methods

	/// Deletes a data from the cache by key.
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func reset(key: String, policy: SavePolicy = .none) async throws {
		cache.removeValue(forKey: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func resetDate(key: String, policy: SavePolicy = .none) async throws {
		cacheDate.removeValue(forKey: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func resetInt(key: String, policy: SavePolicy = .none) async throws {
		cacheInt.removeValue(forKey: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func resetString(key: String, policy: SavePolicy = .none) async throws {
		cacheString.removeValue(forKey: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a data from the cache by key.
	/// - Parameters:
	///   - key: unique key for data.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func resetUUID(key: String, policy: SavePolicy = .none) async throws {
		cacheUUID.removeValue(forKey: key)
		try await resetFromDiscStorage(key, policy)
	}

	/// Deletes a UserPayload from the cache by key.
	/// - Parameter key: unique key for data.
	public func resetPayload(key: String) async throws {
		cachePayload.removeValue(forKey: key)
		try await resetFromDiscStorage(key, .none)
	}

	/// Deletes all data from the cache.
	public func resetAll() throws {
		cacheDate = [:]
		cacheInt = [:]
		cacheString = [:]
		cacheUUID = [:]
		cache = [:]
		cachePayload = [:]

		try storage?.removeAll()
	}

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
	private func removeExpiredMemoryCache() {
		let date: Date = .init()
		for (key, model) in cacheDate {
			if let exp: Date = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cacheInt {
			if let exp: Date = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cacheString {
			if let exp: Date = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cacheUUID {
			if let exp: Date = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cache {
			if let exp: Date = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cachePayload {
			if let exp: Date = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
	}

	/// Deletes all expired keys.
	private func removeExpiredData() async {
		taskFlush = Task(priority: .background) { [weak self] in
			guard let self else { return }
			while true {
				try await self.storage?.reduceDataFile()
				try await Task.sleep(nanoseconds: UInt64(self.memoryFlushInterval * 1_000_000_000))

				await self.removeExpiredMemoryCache()
				try await Task.sleep(nanoseconds: UInt64(self.memoryFlushInterval * 1_000_000_000))
			}
		}
	}

	deinit {
		taskFlush.cancel()
	}
}
