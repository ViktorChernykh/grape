//
//  CacheType.swift
//  Grape
//
//  Created by Victor Chernykh on 23.08.2023.
//

/// Cache type of data for storing.
public enum CacheType: Codable, Sendable {
	case date
	case int
	case model
	case payload
	case string
	case uuid
}
