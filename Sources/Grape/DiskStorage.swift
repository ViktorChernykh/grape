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

	private let decoder: JSONDecoder = .init()
	private let encoder: JSONEncoder = .init()
	private let formatter: DateFormatter = .init()

	// MARK: - Init
	/// Creates a storage folder either in the support directory or in the home directory. Creates the first file to store.
	init(appKey: String) {
		let rootFolder: String = "Grape"
		let cacheFolder: String = "Cache-\(appKey)"

		// Cache folder
		let folder: URL

		let supportFolderURL: URL? = FileManager.default
			.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

		// Build url for cache folder
		if let supportFolderURL {
			folder = supportFolderURL
				.appendingPathComponent(rootFolder)
				.appendingPathComponent(cacheFolder)
		} else {
			let supportFolderPath: String = NSHomeDirectory() + "/.\(rootFolder)/\(cacheFolder)/"
			folder = URL(fileURLWithPath: supportFolderPath)
		}

		// Create cache folder if it doesn't exist
		do {
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
		} catch {
			fatalError("[ ERROR ] Grape: Couldn't create the grape cache directory.")
		}

		// Create current file
		fileURL = folder.appendingPathComponent("data")
		if !FileManager.default.fileExists(atPath: fileURL.path) {
			if !FileManager.default.createFile(atPath: fileURL.path, contents: nil) {
				fatalError("[ ERROR ] Grape: Couldn't create the grape current cache file.")
			}
		}
	}

	// MARK: - Methods

	/// Writes data to end of cache file.
	///
	/// - Parameter cacheModel: data to save.
	func write(_ cacheModel: DiskModel) async throws {
		let data: Data = try encoder.encode(cacheModel) + "\n".data(using: String.Encoding.utf8)!
		let handle: FileHandle = try .init(forWritingTo: fileURL)
		try handle.seekToEnd()
		defer {
			do {
				try handle.close()
			} catch {
				print("[ ERROR ] Grape: Cannot close file \(fileURL.absoluteString). [", #file, #function, #line, "]")
			}
		}
		var result: Bool = false
		for _ in 0...9 {
			do {
				try handle.write(contentsOf: data)
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
	///
	/// - Parameter key: key for cache value.
	func removeValue(forKey key: String) async throws {
		var bateBuffer: Data = .init()

		var i: Int = 0
		for try await line in AsyncFileLines(url: fileURL) {
			i += 1
			// Encode row back to data
			guard let data: Data = line.data(using: String.Encoding.utf8) else {
				print("[ ERROR ] Grape: incorrect data from \(fileURL) at \(i) line. [", #file, #function, #line, "]")
				continue
			}
			// Decode expire date
			guard let item: DiskModel = try? decoder.decode(DiskModel.self, from: data) else {
				print("[ ERROR ] Grape: incorrect data from \(fileURL) at \(i) line. [", #file, #function, #line, "]")
				continue
			}
			// Skip removed data
			if item.key == key {
				continue
			}
			// Restore only the actual data
			bateBuffer.append(data)
		}

		// Source file
		let handle: FileHandle = try .init(forUpdating: fileURL)
		defer {
			do {
				try handle.close()
			} catch {
				print("[ ERROR ] Grape: Cannot close file \(fileURL.absoluteString). [", #file, #function, #line, "]")
			}
		}

		try handle.truncate(atOffset: 0)
		try handle.write(contentsOf: bateBuffer)
	}

	/// Clean file.
	func removeAll() throws {
		// Source file
		let handle: FileHandle = try .init(forUpdating: fileURL)
		defer {
			try? handle.close()
		}
		try handle.truncate(atOffset: 0)
	}

	/// Bootstrap saved cache.
	///
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
		var cacheModel: [String: CacheString] = [:]

		var i: Int = 0
		for try await line in AsyncFileLines(url: fileURL) {
			i += 1
			guard !line.isEmpty else {
				continue
			}
			// Encode row back to data
			guard let data: Data = line.data(using: String.Encoding.utf8) else {
				print("[ ERROR ] Grape: incorrect data from \(fileURL) at \(i) line. [", #file, #function, #line, "]")
				continue
			}
			// Decode disk data
			guard let item: DiskModel = try? decoder.decode(DiskModel.self, from: data) else {
				print("[ ERROR ] Grape: incorrect data from \(fileURL) at \(i) line. [", #file, #function, #line, "]")
				continue
			}
			// Skip expired data
			if let exp: Date = item.exp, exp < Date() {
				continue
			}

			// Restore only the actual data
			switch item.type {
			case .date:
				if let interval: Double = .init(item.body) {
					let date: Date = .init(timeIntervalSince1970: interval)
					cacheDate[item.key] = CacheDate(body: date, exp: item.exp)
				}
			case .int:
				if let int: Int = .init(item.body) {
					cacheInt[item.key] = CacheInt(body: int, exp: item.exp)
				}
			case .string:
				cacheString[item.key] = CacheString(body: item.body, exp: item.exp)
			case .uuid:
				if let uuid: UUID = .init(uuidString: item.body) {
					cacheUUID[item.key] = CacheUUID(body: uuid, exp: item.exp)
				}
			case .model:
				cacheModel[item.key] = CacheString(body: item.body, exp: item.exp)
			}
		}

		return (cacheDate, cacheInt, cacheString, cacheUUID, cacheModel)
	}

	/// Removes obsolete data.
	///
	/// - Throws: if something went wrong.
	func reduceDataFile() async throws {
		var bateBuffer: Data = .init()

		var i = 0
		for try await line in AsyncFileLines(url: fileURL) {
			i += 1
			// Encode row back to data
			guard let data: Data = line.data(using: String.Encoding.utf8) else {
				print("[ ERROR ] Grape: incorrect data from \(fileURL) at \(i) line. [", #file, #function, #line, "]")
				continue
			}
			// Decode expire date
			guard let item: ExpireModel = try? decoder.decode(ExpireModel.self, from: data) else {
				print("[ ERROR ] Grape: incorrect data from \(fileURL) at \(i) line. [", #file, #function, #line, "]")
				continue
			}
			// Skip expired data
			if let exp: Date = item.exp, exp < Date() {
				continue
			}
			// Restore only the actual data
			bateBuffer.append(data)
		}

		// Source file
		let handle: FileHandle = try .init(forUpdating: fileURL)
		defer {
			do {
				try handle.close()
			} catch {
				print("[ ERROR ] Grape: Cannot close file \(fileURL.absoluteString). [", #file, #function, #line, "]")
			}
		}

		try handle.truncate(atOffset: 0)
		try handle.write(contentsOf: bateBuffer)
	}
}
