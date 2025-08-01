//
//  TimeIntervalStorage.swift
//  grape
//
//  Created by Victor Chernykh on 07.07.2025.
//

import Foundation

/// Thread-safe wrapper around a [String: CacheUUID] dictionary.
/// Uses reader–writer lock pattern with a concurrent pthread_rwlock_t.
final class TimeIntervalStorage: @unchecked Sendable, PthreadInitProtocol {

	var lock: pthread_rwlock_t = .init()

	/// Underlying storage (thread-unsafe).
	private var _storage: TimeInterval = 1800	// 30 min

	// MARK: - Init
	init() {
		let message: String? = pthreadInit()
		precondition(message == nil, message ?? "")
	}

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
		let result: Int32 = pthread_rwlock_destroy(&lock)
		precondition(result == 0, "[ FATAL ] Grape: Failed destroy TimeIntervalStorage")
	}
}
