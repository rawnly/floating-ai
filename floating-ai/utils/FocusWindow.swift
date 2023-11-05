//
//  FocusWindow.swift
//  floating-ai
//
//  Created by Federico Vitale on 05/11/23.
//

import Foundation
import Cocoa

final class FocusWindow {
    static func focusWindow(name: String) {
        if !isTrusted() {
            print("Missing Accessibility Permissions")
            return
        }
        
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
       
        guard let window = (windowList.first {
            $0[kCGWindowName as String] != nil && $0[kCGWindowName as String] as! String == name
        }) else {
            print("cannot find window")
            return
        }
        
        guard let number = window[kCGWindowNumber as String] as? Int else {
            return
        }
        
        self.focusWindow(windowNumber: number)
    }
    
    static func focusWindow(windowNumber: Int) {
        if !isTrusted() {
            print("Missing Accessibility Permissions")
            return
        }
        
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
        
        guard
            let cgWindow = (windowList.first { $0[kCGWindowNumber as String] as! Int == windowNumber })
        else {
            print("Window not found")
            return
        }
        
        let ownerPID = cgWindow[kCGWindowOwnerPID as String] as! Int
        
        let maybeIndex = windowList
            .filter { $0[kCGWindowOwnerPID as String] as! Int == ownerPID }
            .firstIndex { $0[kCGWindowNumber as String] as! Int == windowNumber }
        
        guard
            let axWindows = attribute(
                element: AXUIElementCreateApplication(pid_t(ownerPID)),
                key: kAXWindowsAttribute,
                type: [AXUIElement].self
            ),
            let index = maybeIndex,
            axWindows.count > index,
            let app = NSRunningApplication(processIdentifier: pid_t(ownerPID))
        else {
            print("Window not found")
            return
        }
        
        let axWindow = axWindows[index]
        app.activate(options: [.activateAllWindows])
        AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
    }
    
    static func isTrusted(shouldAsk: Bool = false) -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": shouldAsk] as CFDictionary)
    }
    
    private static func attribute<T>(element: AXUIElement, key: String, type: T.Type) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        
        guard
            result == .success,
            let typedValue = value as? T
        else {
            return nil
        }
        
        return typedValue
    }
    
    private static func value<T>(
        element: AXUIElement,
        key: String,
        target: T,
        type: AXValueType
    ) -> T? {
        guard let attribute = self.attribute(element: element, key: key, type: AXValue.self) else {
            return nil
        }
        
        var value = target
        AXValueGetValue(attribute, type, &value)
        return value
    }
}

final class PermissionsService: ObservableObject {
    // Store the active trust state of the app.
    @Published var isTrusted: Bool = AXIsProcessTrusted()

    // Poll the accessibility state every 1 second to check
    //  and update the trust status.
    func pollAccessibilityPrivileges(shouldPrompt prompt: Bool = false) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isTrusted = AXIsProcessTrusted()
            print("Permissions: \(self.isTrusted)")

            if !self.isTrusted {
                if prompt {
                    print("Prompting...")
                    Self.acquireAccessibilityPrivileges()
                }
                
                self.pollAccessibilityPrivileges(shouldPrompt: prompt)
            }
        }
    }

    // Request accessibility permissions, this should prompt
    //  macOS to open and present the required dialogue open
    //  to the correct page for the user to just hit the add
    //  button.
    static func acquireAccessibilityPrivileges() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        let enabled = AXIsProcessTrustedWithOptions(options)
        
        print(enabled, options)
    }
}
