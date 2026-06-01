//
//  ModeSelectView.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
//

// Views/Main/ModeSelectView.swift
import SwiftUI

struct ModeSelectView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 32) {
            Text("Guardian")
                .font(.largeTitle).bold()

            Button("👁 시각장애인 보행 보조") {
                appViewModel.selectedMode = .blind
            }
            .font(.title2)

            Button("🛡 여성 안전 귀가") {
                appViewModel.selectedMode = .safety
            }
            .font(.title2)
        }
        .padding()
    }
}
#Preview {
    ModeSelectView()
        .environmentObject(AppViewModel())
}
