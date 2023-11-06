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
    case ai
}

extension SidebarItem {
    var icon: String {
        switch self {
        case .general:
            return "gear"
        case .ai:
            return "sparkles"
        }
    }
}

struct SettingsView: View {
    @State private var isOn = Preferences.floatingWindow
    @State private var selectedTab = SidebarItem.general
    @State private var showDockIcon = Preferences.showDockIcon
    
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(SidebarItem.allCases, selection: $selectedTab) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue.localizedCapitalized, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .toolbarTitleDisplayMode(.inline)
            .padding(.top, 20)
        } detail: {
            switch selectedTab {
            case .ai:
                SettingsForm {
                    
                }
            case .general:
                SettingsForm {
                    VStack(alignment: .leading)  {
                        HStack {
                            Text("App Activation")
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .activateApp)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 5)
                        
                        HStack {
                            Text("Floating Window")
                            Spacer()
                            Toggle(isOn: $isOn) { EmptyView() }
                            .onChange(of: isOn) { _, newValue in
                                Preferences.floatingWindow = newValue
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 5)
                        
                        HStack {
                            Text("Show Dock Icon")
                            Spacer()
                            Toggle(isOn: $showDockIcon) {
                                EmptyView()
                            }
                            .onChange(of: showDockIcon) { _, newValue in
                                Preferences.showDockIcon = newValue
                            }
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 5)
                    }
                }
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar {}
    }
}

extension KeyboardShortcuts.Name {
    static let activateApp = Self("activateApp")
}


