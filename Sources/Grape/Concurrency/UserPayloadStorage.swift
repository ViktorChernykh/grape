//
//  UserPayloadStorage.swift
//  grape
//
//  Created by Victor Chernykh on 07.07.2025.
//

import Foundation
import TraderUserDto

/// Thread-safe wrapper around a [String: CachePayload] dictionary.
/// Uses reader–writer lock pattern with a concurrent pthread_rwlock_t.
final class UserPayloadStorage: @unchecked Sendable, PthreadInitProtocol {

	var lock: pthread_rwlock_t = .init()

	/// Underlying storage (thread-unsafe).
	private var _storage: [String: CachePayload] = .init()

	// MARK: - Init
	init() {
		let message: String? = pthreadInit()
		precondition(message == nil, message ?? "")
	}

	// MARK: - Methods
	/// Returns value for key.
	func get(for key: String) -> CachePayload? {
		pthread_rwlock_rdlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		return _storage[key]
	}

	func get(for userId: UUID) -> [UserPayload] {
		pthread_rwlock_rdlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		var payloads: [UserPayload] = .init()
		let date: Date = .init()
		for (_, cache) in _storage {
			if cache.body.sub == userId {
				if let exp: Date = cache.exp, exp < date {
					continue
				}
				payloads.append(cache.body)
			}
		}

		return payloads
	}

	/// Sets value for the given key.
	func set(_ value: CachePayload, for key: String) {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage[key] = value
	}

	/// Removes value for key.
	func remove(for key: String) {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		_storage[key] = nil
	}

	/// Removes value for userId.
	func remove(for userId: UUID) -> [String] {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		var keys: [String] = .init()
		for (key, payload) in _storage {
			if payload.body.sub == userId {
				keys.append(key)
			}
		}
		for key in keys {
			_storage[key] = nil
		}
		return keys
	}

	/// Update roleType for user by Id.
	func update(role: Int16, for userId: UUID) -> [String: CachePayload] {
		pthread_rwlock_wrlock(&lock)
		defer {
			pthread_rwlock_unlock(&lock)
		}
		var caches: [String: CachePayload] = .init()
		for (key, cache) in _storage {
			if cache.body.sub == userId {
				caches[key] = cache
			}
		}
		for (key, cache) in caches {
			let new: UserPayload = .init(
				jti: cache.body.jti,
				sub: cache.body.sub,
				firstName: cache.body.firstName,
				lang: cache.body.lang,
				roleLevel: role,
				tariff: cache.body.tariff,
				ip: cache.body.ip
			)
			_storage[key] = CachePayload(body: new, exp: cache.exp)
		}
		return caches
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
	func getAll() -> [String: CachePayload] {
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
		precondition(result == 0, "[FATAL] Grape: Failed destroy UserPayloadStorage")
	}
}
