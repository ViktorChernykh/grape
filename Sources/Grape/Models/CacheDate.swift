//
//  CacheDate.swift
//  Grape
//
//  Created by Victor Chernykh on 15.08.2022.
//

import Foundation

/// Model of data for storage in memory.
public struct CacheDate: Codable {
	// MARK: Stored Properties
	public let body: Date
	public let exp: Date?
	public let policy: SavePolicy

	// MARK: - Init
	public init(
		body: Date,
		exp: Date? = nil,
		policy: SavePolicy = .none
	) {
		self.body = body
		self.exp = exp
		self.policy = policy
	}
}
