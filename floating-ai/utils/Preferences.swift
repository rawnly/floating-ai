//
//  Preferences.swift
//  floating-ai
//
//  Created by Federico Vitale on 05/11/23.
//

import Foundation
import Cocoa


@propertyWrapper
struct StoredValue<T: Codable> {
    private let key: String
    private let defaultValue: T

    init(_ key: String, _ defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    init(key: String, _ defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            // Read value from UserDefaults
            guard let data = UserDefaults.standard.object(forKey: key) as? Data else {
                // Return defaultValue when no data in UserDefaults
                return defaultValue
            }

            // Convert data to the desire data type
            let value = try? JSONDecoder().decode(T.self, from: data)
            return value ?? defaultValue
        }
        
        set {
            // Convert newValue to data
            let data = try? JSONEncoder().encode(newValue)

            // Set value to UserDefaults
            UserDefaults.standard.set(data, forKey: key)
            
            // Synchronize UserDefaults
            UserDefaults.standard.synchronize()
        }
    }
}

final class Preferences {
    @StoredValue("floatingWindow", false)
    static var floatingWindow: Bool {
        didSet {
            print(NSApplication.shared.windows)
            
            for window in NSApplication.shared.windows {
                guard let identifier = window.identifier else { return }
                if identifier.rawValue == "chat" {
                    window.level = floatingWindow ? .modalPanel : .normal
                }
            }
        }
    }
    
    @StoredValue("showDockIcon", false)
    static var showDockIcon: Bool {
        didSet {
            DockIcon.isVisible = showDockIcon
        }
    }
}
