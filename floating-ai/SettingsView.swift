//
//  SettingsView.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import OpenAI
import Foundation
import SwiftUI
import Combine
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
    @ObservedObject var chatStore: ChatStore
    @State private var selectedTab = SidebarItem.general
    
    private var cancellables: [AnyCancellable] = []
    
    @Preference(\.showDockIcon)
    var showDockIcon
    
    @Preference(\.apiKey)
    var apiKey
    
    @Preference(\.floatingWindow)
    var isFloating
    
    @Preference(\.model)
    var model
    
    @Preference(\.temperature)
    var temperature
    
    @Preference(\.autoRenameChat)
    var autoRenameChat
    
    init(chatStore: ChatStore) {
        self.chatStore = chatStore
        
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { $0 == \Preferences.floatingWindow }
            .sink { _ in
                for window in NSApplication.shared.windows {
                    guard let id = window.identifier else {
                        continue
                    }
                    
                    if id.rawValue == "chat" {
                        window.level = Preferences.standard.floatingWindow ? .floating : .normal
                    }
                }
            }
            .store(in: &self.cancellables)
        
        Preferences
            .standard
            .preferencesChangedSubject
            .filter { $0 == \Preferences.showDockIcon }
            .sink { _ in
                DockIcon.isVisible = Preferences.standard.showDockIcon
            }
            .store(in: &self.cancellables)
    }
    
    var body: some View {
        TabView {
            SettingsForm {
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
                    Toggle(isOn: self.$isFloating) { EmptyView() }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
                
                HStack {
                    Text("Show Dock Icon")
                    Spacer()
                    Toggle(isOn: self.$showDockIcon) {
                        EmptyView()
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            SettingsForm {
                HStack {
                    Text("Api Key")
                    Spacer()
                    TextField("", text: self.$apiKey, prompt: Text("YOUR API KEY"))
                        .labelsHidden()
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 300)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 5)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Auto rename conversation")
                        Text("Automagically renames conversation after the first AI response")
                            .font(.caption)
                            .foregroundStyle(Color(nsColor: .textColor).opacity(0.5))
                    }
                    Spacer()
                    Toggle(isOn: self.$autoRenameChat) {
                        EmptyView()
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 5)
                
                Section(header: Text("Default Conversation Settings")) {
                    HStack {
                        Text("GPT Model")
                        Spacer()
                        AIModelPicker(model: self.$model)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 5)
                    
                    HStack {
                        Text("Creativity")
                        Spacer()
                        AITemperaturePicker(temperature: self.$temperature)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 5)
                }
                
            }
            .tabItem {
                Label("AI", systemImage: "sparkle")
            }
        }
    }
}

extension KeyboardShortcuts.Name {
    static let activateApp = Self("activateApp")
}


#Preview {
    SettingsView(chatStore: .init())
}

struct Row<Label: View, Control: View>: View {
    private let label: Label
    private let control: Control
    
    init(label: Label, @ViewBuilder control: () -> Control) {
        self.control = control()
        self.label = label
    }
    
    init(@ViewBuilder control: () -> Control) where Label == EmptyView {
        self.init(label: EmptyView(), control: control)
    }
    
    var body: some View {
        HStack {
            label.alignmentGuide(.centreLine) {
                $0[.leading]
            }
            
            Spacer()
            
            control.alignmentGuide(.centreLine) {
                $0[.trailing]
            }
        }
    }
}



extension HorizontalAlignment {
    private struct CentreLine: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[HorizontalAlignment.center]
        }
    }
    
    static let centreLine = Self(CentreLine.self)
}
