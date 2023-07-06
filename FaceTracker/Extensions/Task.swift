//
//  Task.swift
//  FaceTracker
//
//  Created by Oleg Malovichko on 06.07.2023.
//

import Foundation

extension Task {
    
    public static func sleep(seconds: Double) async throws where Success == Never, Failure == Never {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
