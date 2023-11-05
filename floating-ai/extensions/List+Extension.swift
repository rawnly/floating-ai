//
//  List+Extension.swift
//  floating-ai
//
//  Created by Federico Vitale on 04/11/23.
//

import Foundation
import SwiftUIIntrospect
import SwiftUI

extension List {
    func removeBackground() -> some View {
        self.introspect(.table, on: .macOS(.v14)) { tableView in
            tableView.backgroundColor = .clear
            tableView.enclosingScrollView!.drawsBackground = false
        }
    }
}
