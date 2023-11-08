//
//  SplitView.swift
//  Floating AI
//
//  Created by Federico Vitale on 07/11/23.
//

import SwiftUI

struct SidebarView: View {
    var body: some View {
        List {
            Text("Item")
        }
        .listStyle(SidebarListStyle())
    }
}

struct SplitView: View {
    var body: some View {
        NavigationView {
            SidebarView()
            Text("no sidebar selection")
            Text("no message selection")
        }
    }
}

#Preview {
    SplitView()
}
