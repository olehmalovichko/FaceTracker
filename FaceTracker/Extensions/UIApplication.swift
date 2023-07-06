//
//  UIApplication.swift
//  FaceTracker
//
//  Created by Oleg Malovichko on 04.07.2023.
//

import UIKit

public extension UIApplication {
    var keyWindowFirst: UIWindow? {
        let window = UIApplication
            .shared
            .connectedScenes
            .compactMap {
                ($0 as? UIWindowScene)?.keyWindow
            }
            .first
        return window
    }
}
