// ContentView.swift
// Guardian Blind

import SwiftUI

struct ContentView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var viewModel = BlindViewModel()

    var body: some View {
        if hasCompletedOnboarding {
            BlindView(viewModel: viewModel)
        } else {
            OnboardingView()
        }
    }
}
