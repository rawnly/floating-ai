//
//  AIModelPicker.swift
//  Floating AI
//
//  Created by Federico Vitale on 06/11/23.
//

import SwiftUI
import OpenAI

struct AIModelPicker: View {
    var model: Binding<Model>
    
    var body: some View {
        Picker(selection: self.model) {
            ForEach(ChatStore.availableModels, id: \.self) {
                Text($0.toString())
                    .tag($0)
            }
        } label: { EmptyView() }
            .frame(minWidth: 200)
            .scaledToFill()
            .pickerStyle(SegmentedPickerStyle())
    }
}

struct AITemperaturePicker: View {
    var temperature: Binding<Temperature>
    
    var body: some View {
        Picker(selection: self.temperature) {
            ForEach(Temperature.allCases, id: \.self) {
                Text($0.stringValue)
                    .tag($0)
            }
        } label: { EmptyView() }
            .frame(minWidth: 200)
            .scaledToFill()
    }
}
