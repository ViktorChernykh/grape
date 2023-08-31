//
//  SavePolicy.swift
//  Grape
//
//  Created by Victor Chernykh on 17.08.2022.
//

/// Save policy for storing data.
public enum SavePolicy: Codable {
	/// None save data to persistent storage.
	case none

	/// Async save date to persistent storage.
	case async

	/// Sync save date to persistent storage.
	case sync
}
