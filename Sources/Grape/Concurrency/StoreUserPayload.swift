//
//  StoreUserPayload.swift
//  grape
//
//  Created by Victor Chernykh on 07.07.2025.
//

import Foundation
import TraderUserDto

/// Thread-safe wrapper around a [String: CachePayload] dictionary.
/// Uses reader–writer lock pattern with a concurrent DispatchQueue.
final class StoreUserPayload {

	private let queue: DispatchQueue = .init(
		label: "grape.payloadQueue",
		attributes: .concurrent
	)

	/// Underlying storage (thread-unsafe).
	private var _storage: [String: CachePayload] = .init()

	// MARK: - Init
	init() { }

	// MARK: - Methods
	/// Returns value for key.
	func get(for key: String) -> CachePayload? {
		queue.sync {
			_storage[key]
		}
	}

	/// Sets value for the given key.
	func set(_ value: CachePayload, for key: String) {
		queue.async(flags: .barrier) {
			self._storage[key] = value
		}
	}

	/// Removes value for key.
	func remove(for key: String) {
		queue.async(flags: .barrier) {
			self._storage[key] = nil
		}
	}

	/// Clear dictionary.
	func clear() {
		queue.async(flags: .barrier) {
			self._storage = [:]
		}
	}

	/// Extracts the entire dictionary.
	func getAll() -> [String: CachePayload] {
		queue.sync {
			_storage
		}
	}

	/// Removes all expired data.
	func removeExpiredData() {
		let date: Date = .init()
		for (key, model) in getAll() {
			if let exp: Date = model.exp, exp < date {
				remove(for: key)
			}
		}
	}
}
