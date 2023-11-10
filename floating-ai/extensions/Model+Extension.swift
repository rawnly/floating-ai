//
//  Model+Extension.swift
//  Floating AI
//
//  Created by Federico Vitale on 07/11/23.
//

import Foundation
import OpenAI

//public extension Model {
//    static let gpt4_1106_preview = "gpt-4-1106-preview"
//    static let gpt4_vision_preview = "gpt-4-vision-preview"
//    static let gpt3_5Turbo_1106 = "gpt-3.5-turbo-1106"
//}

extension Model {
    func toString() -> String {
        #if !DEBUG
            return self
        #else
        switch self {
        case .gpt4_1106_preview:
            return "GPT-4 Turbo"
        case .gpt4_vision_preview:
            return "GPT-4 Vision"
        case .gpt4,
                .gpt4_32k,
                .gpt4_0613,
                .gpt4_32k_0613,
                .gpt4_32k_0314:
            return "GPT-4"
        case .gpt3_5Turbo, .gpt3_5Turbo0613, .gpt3_5Turbo_16k, .gpt3_5Turbo_1106, .gpt3_5Turbo_16k_0613:
            return "GPT-3"
        default:
            return self
        }
        #endif
    }
}
