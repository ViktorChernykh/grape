//
//  PthreadInitProtocol.swift
//  Grape
//
//  Created by Victor Chernykh on 01.08.2025.
//

import Foundation

protocol PthreadInitProtocol: AnyObject {
	var lock: pthread_rwlock_t { get set }
}

extension PthreadInitProtocol {
	func pthreadInit(maxRetry: Int = 3, retryDelay: Double = 0.1) -> String? {
		var retry: Int = 0

		while true {
			let result: Int32 = pthread_rwlock_init(&lock, nil)

			switch result {
			case 0:
				return nil // success

			case EAGAIN,	// Not enough system resources to initialize the read-write lock
				 ENOMEM:	// There is not enough memory to initialize the lock
				// Retry after a short delay
				if retry < maxRetry {
					retry += 1
					Thread.sleep(forTimeInterval: retryDelay)
					continue
				} else {
					let error: String = "[FATAL] pthread_rwlock_init failed after \(retry) retries"
					print(error)
					return error	// fallback to no-lock mode (or fatalError if required)
				}

			case EINVAL:	// The attr specified in the rwlock parameter is invalid.
				let error: String = "[FATAL] pthread_rwlock_init failed with EINVAL: invalid attributes"
				print(error)
				return error

			default:
				// Unknown fatal error
				let error: String = "[FATAL] pthread_rwlock_init failed with unknown error code \(result)"
				print(error)
				return error
			}
		}
	}
}
