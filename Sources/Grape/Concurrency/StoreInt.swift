//
//  StoreInt.swift
//  grape
//
//  Created by Victor Chernykh on 07.07.2025.
//

import Foundation

/// Thread-safe wrapper around a [String: CacheInt] dictionary.
/// Uses reader–writer lock pattern with a concurrent DispatchQueue.
final class StoreInt {

	private let queue: DispatchQueue = .init(
		label: "grape.intQueue",
		attributes: .concurrent
	)

	/// Underlying storage (thread-unsafe).
	private var _storage: [String: CacheInt] = .init()

	// MARK: - Init
	init() { }

	// MARK: - Methods
	/// Returns value for key.
	func get(for key: String) -> CacheInt? {
		queue.sync {
			_storage[key]
		}
	}

	/// Sets value for the given key.
	func set(_ value: CacheInt, for key: String) {
		queue.async(flags: .barrier) {
			self._storage[key] = value
		}
	}

	/// Sets initial values.
	func setInit(_ values: [String: CacheInt]) {
		queue.async(flags: .barrier) {
			self._storage = values
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
	func getAll() -> [String: CacheInt] {
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
