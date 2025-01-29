//
//  CachePayload.swift
//
//
//  Created by Victor Chernykh on 10.04.2024.
//

import struct Foundation.Date
import TraderUserDto

/// Model of data for storage in memory.
public struct CachePayload: Codable {
	// MARK: Stored Properties
	public let body: UserPayload
	public let exp: Date?

	// MARK: - Init
	public init(
		body: UserPayload,
		exp: Date? = nil
	) {
		self.body = body
		self.exp = exp
	}
}
