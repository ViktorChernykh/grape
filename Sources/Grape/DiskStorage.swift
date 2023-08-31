//
//  DiskStorage.swift
//  Grape
//
//  Created by Victor Chernykh on 14.08.2022.
//

import Foundation

/// Class for managing cache storage.
struct DiskStorage: StorageProtocol {
	// MARK: Stored Properties
	/// Name for current cache file
	private let fileURL: URL

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()
	private let formatter = DateFormatter()

	// MARK: - Init
	/// Creates a storage folder either in the support directory or in the home directory. Creates the first file to store.
	/// - Parameters:
	///   - folderName: name of folder for storage.
	///   - pathComponents: path components for add to Support Directory.
	init(
		folder folderName: String = "Grape",
		cacheFolder: String = "Cache",
		cacheFileName: String = "data"
	) {
		let folder: URL
		let supportFolderURL = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
		if let supportFolderURL {
			folder = supportFolderURL
				.appendingPathComponent(folderName)
				.appendingPathComponent(cacheFolder)
		} else {
			let supportFolderPath = NSHomeDirectory() + "/.\(folderName)/\(cacheFolder)/"
			folder = URL(fileURLWithPath: supportFolderPath)
		}
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		} catch {
			fatalError("Grape error: Couldn't create the grape cache directory.")
		}

		fileURL = folder.appendingPathComponent(cacheFileName)
		if !FileManager.default.fileExists(atPath: fileURL.path) {
			if !FileManager.default.createFile(atPath: fileURL.path, contents: nil) {
				fatalError("Grape error: Couldn't create the grape current cache file.")
			}
		}
	}

	// MARK: - Methods

	/// Writes data to end of cache file.
	/// - Parameter cacheModel: data to save.
	func write(_ cacheModel: DiskModel) async throws {
		let data = try encoder.encode(cacheModel) + "\n".data(using: .utf8)!

		var result = false
		for _ in 0...24 {
			do {
				let fileHandle = try FileHandle(forWritingTo: fileURL)
				fileHandle.seekToEndOfFile()
				try fileHandle.write(contentsOf: data)
				try fileHandle.close()
				result = true
				break
			} catch {
				try await Task.sleep(nanoseconds: UInt64(5_000_000_000))
			}
		}
		if !result {
			throw GrapeError.couldNotWriteToCacheFile
		}
	}

	/// Deletes the value from the file by the specified key.
	/// - Parameter key: key for cache value.
	func removeValue(forKey key: String) async throws {
		var bateBuffer = Data()
		// Source file
		let handle = try FileHandle(forUpdating: fileURL)

		var i = 0
		for try await line in handle.bytes.lines {
			i += 1
			// encode row back to data
			guard let data = line.data(using: .utf8) else {
				print("Grape error: incorrect data from \(fileURL) at \(i) line.")
				continue
			}
			// decode expire date
			guard let item = try? decoder.decode(DiskModel.self, from: data) else {
				print("Grape error: incorrect data from \(fileURL) at \(i) line.")
				continue
			}
			// skip removed data
			if item.key == key {
				continue
			}
			// restore only the actual data
			bateBuffer.append(data)
		}

		try handle.truncate(atOffset: 0)
		try handle.write(contentsOf: bateBuffer)
		try handle.close()
	}

	/// Clean file.
	func removeAll() throws {
		// Source file
		let handle = try FileHandle(forUpdating: fileURL)
		try handle.truncate(atOffset: 0)
		try handle.close()
	}

	/// Bootstrap saved cache.
	/// - Returns: dictionary of cached data.
	func loadCache() async throws -> (
		[String: CacheDate],
		[String: CacheInt],
		[String: CacheString],
		[String: CacheUUID],
		[String: CacheString]
	) {
		var cacheDate: [String: CacheDate] = [:]
		var cacheInt: [String: CacheInt] = [:]
		var cacheString: [String: CacheString] = [:]
		var cacheUUID: [String: CacheUUID] = [:]
		var cache: [String: CacheString] = [:]

		// Source file
		let handle = try FileHandle(forUpdating: fileURL)

		var i = 0
		for try await line in handle.bytes.lines {
			i += 1
			// encode row back to data
			guard let data = line.data(using: .utf8) else {
				print("Grape error: incorrect data from \(fileURL) at \(i) line.")
				continue
			}
			// decode disk data
			guard let item = try? decoder.decode(DiskModel.self, from: data) else {
				print("Grape error: incorrect data from \(fileURL) at \(i) line.")
				continue
			}
			// skip expired data
			if let exp = item.exp, exp < Date() {
				continue
			}

			// restore only the actual data
			switch item.type {
			case .date:
				if let body = formatter.date(from: item.body) {
					cacheDate[item.key] = CacheDate(body: body, exp: item.exp)
				}
			case .int:
				if let body = Int(item.body) {
					cacheInt[item.key] = CacheInt(body: body, exp: item.exp)
				}
			case .string:
				cacheString[item.key] = CacheString(body: item.body, exp: item.exp)
			case .uuid:
				if let body = UUID(uuidString: item.body) {
					cacheUUID[item.key] = CacheUUID(body: body, exp: item.exp)
				}
			default:
				cache[item.key] = CacheString(body: item.body, exp: item.exp)
			}
		}
		try handle.close()

		return (cacheDate, cacheInt, cacheString, cacheUUID, cache)
	}

	/// Removes obsolete data.
	/// - Throws: if something went wrong.
	func reduceDataFile() async throws {
		var bateBuffer = Data()
		// Source file
		let handle = try FileHandle(forUpdating: fileURL)

		var i = 0
		for try await line in handle.bytes.lines {
			i += 1
			// encode row back to data
			guard let data = line.data(using: .utf8) else {
				print("Grape error: incorrect data from \(fileURL) at \(i) line.")
				continue
			}
			// decode expire date
			guard let item = try? decoder.decode(ExpireModel.self, from: data) else {
				print("Grape error: incorrect data from \(fileURL) at \(i) line.")
				continue
			}
			// skip expired data
			if let exp = item.exp, exp < Date() {
				continue
			}
			// restore only the actual data
			bateBuffer.append(data)
		}

		try handle.truncate(atOffset: 0)
		try handle.write(contentsOf: bateBuffer)
		try handle.close()
	}
}
