//
//  DiskModel.swift
//  Grape
//
//  Created by Victor Chernykh on 15.08.2022.
//

import struct Foundation.Date

/// Model for storing to local file.
public struct DiskModel: Codable, Sendable {
	// MARK: Stored Properties
	public let body: String
	public let exp: Date?
	public let key: String
	public let type: CacheType

	// MARK: - Init
	public init(
		body: String,
		exp: Date? = nil,
		key: String,
		type: CacheType
	) {
		self.body = body
		self.exp = exp
		self.key = key
		self.type = type
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		body = try container.decode(String.self, forKey: .body)
		exp = try container.decode(Date.self, forKey: .exp)
		key = try container.decode(String.self, forKey: .key)
		type = try container.decode(CacheType.self, forKey: .type)
	}
}
