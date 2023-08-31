//
//  GrapeDatabase.swift
//  Grape
//
//  Created by Victor Chernykh on 14.08.2022.
//

import Foundation

public actor GrapeDatabase {
	// MARK: Stored Properties
	public static var shared = GrapeDatabase()

	/// Cache flush Interval in seconds.
	public var memoryFlushInterval: Double = 1800

	/// Disk storage delegate.
	var storage: StorageProtocol?

	private var cacheDate: [String: CacheDate] = [:]
	private var cacheInt: [String: CacheInt] = [:]
	private var cacheString: [String: CacheString] = [:]
	private var cacheUUID: [String: CacheUUID] = [:]
	private var cache: [String: CacheString] = [:]

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()
	private let formatter = DateFormatter()

	// MARK: - Init
	private init() {
		do {
			try removeExpiredData()
		} catch {
			print(error.localizedDescription)
		}
	}

	// MARK: - Methods
	/// Load the data from cache file.
	public func setupStorage(cacheFolder: String = "Cache") async throws {
		storage = DiskStorage(cacheFolder: cacheFolder)
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

	// MARK: - Get

	/// Get data from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	///   - as: type for decode data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func get<T: Codable>(by key: String, as: T.Type) throws -> T? {
		guard let model = cache[key] else {
			return nil
		}
		if let exp = model.exp, exp < Date() {
			// The data has expired
			return nil
		}

		guard let data = model.body.data(using: .utf8) else {
			return nil
		}
		return try decoder.decode(T.self, from: data)
	}

	/// Get string from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func getString(by key: String) throws -> CacheString? {
		guard let model = cacheString[key] else {
			return nil
		}
		if let exp = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model
	}

	/// Get date from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func getDate(by key: String) throws -> CacheDate? {
		guard let model = cacheDate[key] else {
			return nil
		}
		if let exp = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model
	}

	/// Get integer from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func getInt(by key: String) throws -> CacheInt? {
		guard let model = cacheInt[key] else {
			return nil
		}
		if let exp = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model
	}

	/// Get uuid from memory cache.
	/// - Parameters:
	///   - key: unique key for search data.
	/// - Returns: decoded data or nil if it not found or catch an error.
	public func getUUID(by key: String) throws -> CacheUUID? {
		guard let model = cacheUUID[key] else {
			return nil
		}
		if let exp = model.exp, exp < Date() {
			// The data has expired
			return nil
		}
		return model
	}

	// MARK: - Set

	/// Store an object to memory cache and to disk.
	/// - Parameters:
	///   - model: object for save.
	///   - key: unique key for search data.
	///   - exp: expiration date.
	///   - policy: disk save policy: `.none` `.sync` `.async` .
	public func set<T: Codable>(_ model: T, for key: String, exp: Date? = nil, policy: SavePolicy = .none) async throws {
		let data = try encoder.encode(model)
		let string = String(data: data, encoding: .utf8) ?? ""
		let cacheValue = CacheString(body: string, exp: exp)
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
		let cacheValue = CacheString(body: value, exp: exp)
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
		let cacheValue = CacheDate(body: value, exp: exp)
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
		let cacheValue = CacheInt(body: value, exp: exp)
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
		let cacheValue = CacheUUID(body: value, exp: exp)
		cacheUUID[key] = cacheValue
		try await setToDiscStorage(value: value.uuidString, exp: exp, key: key, policy: policy, type: .uuid)
	}

	private func setToDiscStorage(value: String, exp: Date?, key: String, policy: SavePolicy, type: CacheType) async throws {
		switch policy {
		case .none:
			return
		case .async:
			Task(priority: .medium) { [weak self] in
				let diskModel = DiskModel(body: value, exp: exp, key: key, type: .uuid)
				try await self?.storage?.write(diskModel)
			}
		case .sync:
			let diskModel = DiskModel(body: value, exp: exp, key: key, type: .uuid)
			try await storage?.write(diskModel)
		}
	}

	// MARK: - Reset

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

	/// Deletes all data from the cache.
	public func resetAll() throws {
		cacheDate = [:]
		cacheInt = [:]
		cacheString = [:]
		cacheUUID = [:]
		cache = [:]

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

	// MARK: - Remove

	/// Deletes all expired keys.
	private func removeExpiredMemoryCache() {
		let date = Date()
		for (key, model) in cacheDate {
			if let exp = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cacheInt {
			if let exp = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cacheString {
			if let exp = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cacheUUID {
			if let exp = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
		for (key, model) in cache {
			if let exp = model.exp, exp < date {
				cache.removeValue(forKey: key)
			}
		}
	}

	/// Deletes all expired keys.
	nonisolated
	private func removeExpiredData() throws {
		Task(priority: .background) { [weak self] in
			guard let self else { return }
			while true {
				try await self.storage?.reduceDataFile()
				try await Task.sleep(nanoseconds: UInt64(self.memoryFlushInterval * 1_000_000_000))

				await self.removeExpiredMemoryCache()
				try await Task.sleep(nanoseconds: UInt64(self.memoryFlushInterval * 1_000_000_000))
			}
		}
	}
}
