//
//  CacheDate.swift
//  Grape
//
//  Created by Victor Chernykh on 15.08.2022.
//

import struct Foundation.Data
import struct Foundation.Date

/// Model of data for storage in memory.
public struct CacheDate: Codable {
	// MARK: Stored Properties
	public let body: Date
	public let exp: Date?

	// MARK: - Init
	public init(
		body: Date,
		exp: Date? = nil
	) {
		self.body = body
		self.exp = exp
	}
}
