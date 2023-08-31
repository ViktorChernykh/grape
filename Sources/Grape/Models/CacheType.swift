//
//  CacheType.swift
//  Grape
//
//  Created by Victor Chernykh on 23.08.2023.
//

/// Cache type of data for storing.
public enum CacheType: Codable {
	case date
	case int
	case model
	case string
	case uuid
}
