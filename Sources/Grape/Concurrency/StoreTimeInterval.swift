//
//  StoreTimeInterval.swift
//  grape
//
//  Created by Victor Chernykh on 07.07.2025.
//

import Foundation

/// Thread-safe wrapper around a [String: CacheUUID] dictionary.
/// Uses reader–writer lock pattern with a concurrent pthread_rwlock_t.
final class StoreTimeInterval: @unchecked Sendable {

	private var lock: pthread_rwlock_t = .init()

	/// Underlying storage (thread-unsafe).
	private var _storage: TimeInterval = 1800	// 30 min

	// MARK: - Init
	init() { }

	// MARK: - Methods
	/// Returns value for key.
	func get() -> TimeInterval {
		pthread_rwlock_rdlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		return _storage
	}

	/// Sets value for the given key.
	func set(_ value: TimeInterval) {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage = value
	}

	deinit {
		pthread_rwlock_destroy(&lock)
	}
}
