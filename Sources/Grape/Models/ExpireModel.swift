//
//  ExpireModel.swift
//  Grape
//
//  Created by Victor Chernykh on 15.08.2022.
//

import struct Foundation.Date

/// A model for decoding an expiration date from the data.
public struct ExpireModel: Codable {
	// MARK: Stored Properties
	public let exp: Date?

	// MARK: - Init
	public init(exp: Date? = nil) {
		self.exp = exp
	}
}
