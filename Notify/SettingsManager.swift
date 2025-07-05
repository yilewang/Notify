
//  SettingsManager.swift
//  Notify
//
//  Created by Yile Wang on 7/4/25.
//

import Foundation

struct SettingsManager {
    static var logDefaultDelivery: Bool {
        UserDefaults.standard.bool(forKey: "logDefaultDelivery")
    }
}
