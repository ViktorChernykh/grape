//
//  AsyncFileLines.swift
//  grape
//
//  Created by Victor Chernykh on 20.05.2025.
//

import Foundation

/// Async sequence that yields the contents of a file **line-by-line**.
///
/// The implementation relies only on the APIs that exist in all Foundation builds,
/// so it builds the same way on Linux and Apple OS.
///
/// Example usage (inside async context)
///
///		let url: URL = .init(fileURLWithPath: "/var/log/syslog")
///		for try await line in AsyncFileLines(url: url) {
///			print(line)
///		}
public struct AsyncFileLines: AsyncSequence {

	// MARK: Types

	public typealias Element = String

	public final class AsyncIterator: AsyncIteratorProtocol {

		// MARK: Constants

		/// "\n" in UTF-8.
		private static let newline = Data([0x0A])

		// MARK: Stored properties

		private let handle: FileHandle               // File descriptor owner
		private let chunkSize: Int                   // Read buffer size
		private let encoding: String.Encoding        // Text encoding
		private var buffer = Data()                  // Accumulated bytes between reads

		// MARK: Init

		init(
			fileURL url: URL,
			chunkSize: Int,
			encoding: String.Encoding
		) throws {
			self.handle = try .init(forReadingFrom: url)
			self.chunkSize = chunkSize
			self.encoding = encoding
		}

		// MARK: AsyncIteratorProtocol

		public func next() async throws -> String? {
			// Look for “\n” in the buffered data; if found — emit a line.
			while true {
				if let range: Range<Data.Index> = buffer.firstRange(of: Self.newline) {
					let lineData: Data = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
					buffer.removeSubrange(buffer.startIndex...range.lowerBound)
					return String(data: lineData, encoding: encoding)
				}

				// Read the next chunk from disk; empty chunk → EOF.
				guard let chunk: Data = try handle.read(upToCount: chunkSize), !chunk.isEmpty else {
					defer {
						buffer.removeAll()
					}
					return buffer.isEmpty ? nil : String(data: buffer, encoding: encoding)
				}
				buffer.append(chunk)		// Accumulate and loop again.
			}
		}

		deinit {
			// Close FD at end-of-file
			try? handle.close()
			buffer.removeAll()
		}
	}

	// MARK: Stored properties

	private let url: URL
	private let chunkSize: Int
	private let encoding: String.Encoding

	// MARK: Init

	/// - Parameters:
	///   - url: Path to the text file.
	///   - chunkSize: Size (in bytes) of a single read operation. Default is 8 KiB.
	///   - encoding: Character encoding. Default is `.utf8`.
	public init(
		url: URL,
		chunkSize: Int = 8 * 1024,
		encoding: String.Encoding = .utf8
	) {
		self.url = url
		self.chunkSize = chunkSize
		self.encoding = encoding
	}

	// MARK: AsyncSequence

	public func makeAsyncIterator() -> AsyncIterator {
		// Fatal error here is acceptable: construction already throws above.
		try! .init(fileURL: url, chunkSize: chunkSize, encoding: encoding)
	}
}
