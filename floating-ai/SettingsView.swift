//
//  SettingsView.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import SwiftUI
import KeyboardShortcuts

enum Tabs: Hashable {
    case Shortcuts, General
}

enum SidebarItem: String, Identifiable, CaseIterable {
    var id: String { rawValue }
    
    case general
    case keystrokes
}

extension SidebarItem {
    var icon: String {
        switch self {
        case .general:
            return "gear"
        case .keystrokes:
            return "keyboard"
        }
    }
}

struct SettingsView: View {
    @State private var isOn = false
    @State private var selectedTab = SidebarItem.general
    
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SidebarItem.allCases, selection: $selectedTab) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue.localizedCapitalized, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selectedTab {
            case .keystrokes:
                SettingsForm {
                    Color.red.frame(width: 50, height: 50)
                }
            case .general:
                SettingsForm {
                    VStack(alignment: .leading)  {
                        HStack {
                            Text("App Activation:")
                            KeyboardShortcuts.Recorder(for: .activateApp)
                        }
                        HStack {
                            Toggle(isOn: $isOn) {
                                Text("Floating Window:")
                            }
                            .toggleStyle(.checkbox)
                            .onChange(of: isOn) { _, newValue in
                                print(isOn)
                            }
                        }
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

extension KeyboardShortcuts.Name {
    static let activateApp = Self("activateApp")
}


struct SettingsPreview: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
