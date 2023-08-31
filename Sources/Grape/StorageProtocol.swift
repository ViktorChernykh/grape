//
//  StorageProtocol.swift
//  Grape
//
//  Created by Victor Chernykh on 17.06.2023.
//

public protocol StorageProtocol {
	func write(_ value: DiskModel) async throws
	func loadCache() async throws -> (
		[String: CacheDate],
		[String: CacheInt],
		[String: CacheString],
		[String: CacheUUID],
		[String: CacheString]
	)
	func reduceDataFile() async throws
	func removeValue(forKey key: String) async throws
	func removeAll() throws
}
