//
//  DemoView.swift
//  Floating AI
//
//  Created by Federico Vitale on 08/11/23.
//

import SwiftUI

struct DemoView: View {
    @ObservedObject
    private var vm: ConversationsVM = .init()
    
    @State private var textFieldValue: String = ""
    
    var body: some View {
        NavigationSplitView {
            List(selection: Binding<Conversation.ID?>(
                get: {
                    self.vm.selectedConversationID
                },
                set: {
                    self.vm.selectedConversationID = $0
                }
            )) {
                ForEach(self.$vm.conversations, id: \.id) { $conversation in
                    Text(conversation.displayName)
                        .tag(conversation.id)
                }
            }
        } detail: {
            if let conversation = self.vm.selectedConversation {
                ZStack(alignment: .bottom) {
                    ScrollView {
                        VStack {
                            ForEach(conversation.messages, id: \.id) { message in
                                ChatBubble(message: message)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack {
                        TextField("", text: .constant("message"))
                    }
                }
                .padding()
                .onDrop(of: [.fileURL], isTargeted: .constant(true), perform: { providers in
                    providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url", completionHandler: { (data, error) in
                        if let data = data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                            let image = NSImage(contentsOf: url)
                            print(image, path)
//                            DispatchQueue.main.async {
//                                self.image = image
//                            }
                        }
                    })

                    return true
                })
                
            } else {
                Text("please select an item from the list")
            }
        }
        .toolbar(content: {
            ToolbarItemGroup {
                Button {
                    self.vm.newConversation()
                } label: {
                    Label("New Conversation", systemImage: "plus")
                }
                
                Button {
                    self.vm.clearConversation(self.vm.selectedConversationID)
                } label: {
                    Label("Clear Conversation", systemImage: "eraser.fill")
                }
                
                Button {
                    self.vm.deleteConversation(self.vm.selectedConversationID)
                } label: {
                    Label("Delete Conversation", systemImage: "trash.fill")
                }
            }
        })

    }
}

#Preview {
    DemoView()
}
