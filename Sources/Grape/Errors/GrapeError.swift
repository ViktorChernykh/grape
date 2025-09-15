//
//  GrapeError.swift
//  Grape
//
//  Created by Victor Chernykh on 14.08.2022.
//

/// Library's Errors
enum GrapeError: Error, Sendable {
	case couldNotWriteToCacheFile
	case dataFileNoExists
}

extension GrapeError {
	var reason: String {
		switch self {
		case .couldNotWriteToCacheFile:
			return "Could not write to cache file."
		case .dataFileNoExists:
			return "Data file no exists."
		}
	}
}
