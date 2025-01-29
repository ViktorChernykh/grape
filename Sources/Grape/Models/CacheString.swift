//
//  CacheString.swift
//  Grape
//
//  Created by Victor Chernykh on 15.08.2022.
//

import struct Foundation.Date

/// Model of data for storage in memory.
public struct CacheString: Codable {
	// MARK: Stored Properties
	public let body: String
	public let exp: Date?

	// MARK: - Init
	public init(
		body: String,
		exp: Date? = nil
	) {
		self.body = body
		self.exp = exp
	}
}
