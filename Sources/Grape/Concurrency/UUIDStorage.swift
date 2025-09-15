//
//  UUIDStorage.swift
//  grape
//
//  Created by Victor Chernykh on 07.07.2025.
//

import Foundation

/// Thread-safe wrapper around a [String: CacheUUID] dictionary.
/// Uses reader–writer lock pattern with a concurrent pthread_rwlock_t.
final class UUIDStorage: @unchecked Sendable, PthreadInitProtocol {

	var lock: pthread_rwlock_t = .init()

	/// Underlying storage (thread-unsafe).
	private var _storage: [String: CacheUUID] = .init()

	// MARK: - Init
	init() {
		let message: String? = pthreadInit()
		precondition(message == nil, message ?? "")
	}

	// MARK: - Methods
	/// Returns value for key.
	func get(for key: String) -> CacheUUID? {
		pthread_rwlock_rdlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		return _storage[key]
	}

	/// Sets value for the given key.
	func set(_ value: CacheUUID, for key: String) {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage[key] = value
	}

	/// Sets initial values.
	func setInit(_ values: [String: CacheUUID]) {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage = values
	}

	/// Removes value for key.
	func remove(for key: String) {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage[key] = nil
	}

	/// Clear dictionary.
	func clear() {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage = [:]
	}

	/// Extracts the entire dictionary.
	func getAll() -> [String: CacheUUID] {
		pthread_rwlock_rdlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		return _storage
	}

	/// Removes all expired data.
	func removeExpiredData() {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}

		let currentDate: Date = .init()
		_storage = _storage.filter { _, value in
			if let exp: Date = value.exp, exp < currentDate {
				return false
			}
			return true
		}
	}

	deinit {
		let result: Int32 = pthread_rwlock_destroy(&lock)
		precondition(result == 0, "[FATAL] Grape: Failed destroy UUIDStorage")
	}
}
