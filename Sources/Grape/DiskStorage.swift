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
	/// URL for cache file.
	private let fileURL: URL

	private let decoder = JSONDecoder()
	private let encoder = JSONEncoder()
	private let formatter = DateFormatter()

	// MARK: - Init
	/// Creates a storage folder either in the support directory or in the home directory. Creates the first file to store.
	init(appKey: String) {
		let rootFolder = "Grape"
		let cacheFolder = "Cache-\(appKey)"
		
		// Cache folder
		let folder: URL

		let supportFolderURL = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

		// Build url for cache folder
		if let supportFolderURL {
			folder = supportFolderURL
				.appendingPathComponent(rootFolder)
				.appendingPathComponent(cacheFolder)
		} else {
			let supportFolderPath = NSHomeDirectory() + "/.\(rootFolder)/\(cacheFolder)/"
			folder = URL(fileURLWithPath: supportFolderPath)
		}

		// Create cache folder if it doesn't exist
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		} catch {
			fatalError("Grape error: Couldn't create the grape cache directory.")
		}

		// Create current file
		fileURL = folder.appendingPathComponent("data")
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
		for _ in 0...9 {
			do {
				let fileHandle = try FileHandle(forWritingTo: fileURL)
				fileHandle.seekToEndOfFile()
				try fileHandle.write(contentsOf: data)
				try fileHandle.close()
				result = true
				break
			} catch {
				try await Task.sleep(nanoseconds: UInt64(10_000_000_000))
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
		defer {
			do {
				try handle.close()
			} catch {
				print("Grape error: Cannot close file \(fileURL.absoluteString).")
			}
		}

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
		defer {
			do {
				try handle.close()
			} catch {
				print("Grape error: Cannot close file \(fileURL.absoluteString).")
			}
		}

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
				if let date = formatter.date(from: item.body) {
					cacheDate[item.key] = CacheDate(body: date, exp: item.exp)
				}
			case .int:
				if let int = Int(item.body) {
					cacheInt[item.key] = CacheInt(body: int, exp: item.exp)
				}
			case .string:
				cacheString[item.key] = CacheString(body: item.body, exp: item.exp)
			case .uuid:
				if let uuid = UUID(uuidString: item.body) {
					cacheUUID[item.key] = CacheUUID(body: uuid, exp: item.exp)
				}
			case .model:
				cache[item.key] = CacheString(body: item.body, exp: item.exp)
			}
		}

		return (cacheDate, cacheInt, cacheString, cacheUUID, cache)
	}

	/// Removes obsolete data.
	/// - Throws: if something went wrong.
	func reduceDataFile() async throws {
		var bateBuffer = Data()
		// Source file
		let handle = try FileHandle(forUpdating: fileURL)
		defer {
			do {
				try handle.close()
			} catch {
				print("Grape error: Cannot close file \(fileURL.absoluteString).")
			}
		}

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
	}
}
