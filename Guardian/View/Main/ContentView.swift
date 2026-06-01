//
//  ContentView.swift
//  Guardian
//
//  Created by 정윤수 on 5/31/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel()

        var body: some View {
            Group {
                switch appViewModel.selectedMode {
                case .blind:
                    BlindView()
                case .safety:
                    SafetyView()
                case .none:
                    ModeSelectView()
                }
            }
            .environmentObject(appViewModel)
    }
}
#Preview {
    ContentView()
}
