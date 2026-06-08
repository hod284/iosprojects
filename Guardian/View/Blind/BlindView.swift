// BlindView.swift
// Guardian Blind
//
// 시각장애인용 메인 화면.
// 화면을 볼 필요 없음 — 탭으로만 조작, 모든 피드백은 TTS.
// 앱 켜지는 순간 백그라운드에서 LiDAR/TTS 자동 시작.
//
// 하단 왼쪽 절반 탭  → 읽어줘 (OCR)
// 하단 오른쪽 절반 탭 → 출입구 찾기
// 우상단 설정 버튼은 보호자/타인이 쓰는 용도

import SwiftUI

struct BlindView: View {

    @ObservedObject var viewModel: BlindViewModel
    @State private var showSettings = false
    @State private var showReadIt = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 하단 좌우 탭 영역 (시각장애인 조작 영역)
            bottomTapZone

            // 설정 버튼 — 보호자용, 우상단 작게
            settingsButton
        }
        .onAppear {
            viewModel.start()
            // 앱 시작 알림
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.announceStart()
            }
        }
        .onDisappear {
            viewModel.stop()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showReadIt) {
            ReadItView()
        }
        // VoiceOver: 전체를 두 영역으로만 노출
        .accessibilityElement(children: .contain)
    }

    // MARK: - 하단 좌우 탭 영역

    private var bottomTapZone: some View {
        GeometryReader { geo in
            VStack {
                Spacer()

                HStack(spacing: 0) {
                    // ── 왼쪽 절반: 읽어줘 ──
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { handleReadIt() }
                        .frame(width: geo.size.width / 2, height: 180)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("읽어줘. 카메라로 글자를 읽어드립니다.")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { handleReadIt() }

                    // ── 오른쪽 절반: 출입구 찾기 ──
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { handleEntrance() }
                        .frame(width: geo.size.width / 2, height: 180)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("출입구 찾기. 주변 출입구를 찾아드립니다.")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { handleEntrance() }
                }
                .frame(height: 180)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - 설정 버튼 (보호자용)

    private var settingsButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(20)
                }
                .accessibilityLabel("설정")
            }
            Spacer()
        }
    }

    // MARK: - 액션

    private func handleReadIt() {
        viewModel.speak("읽어줘를 시작합니다", priority: .warning)
        showReadIt = true
    }

    private func handleEntrance() {
        viewModel.startEntranceSearch()
    }
}
