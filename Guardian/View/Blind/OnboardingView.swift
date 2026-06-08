// OnboardingView.swift
// Guardian Blind
//
// 시각장애인용 온보딩.
// 화면을 볼 필요 없음 — 탭하면 TTS가 안내하고 권한 요청함.

import SwiftUI
import AVFoundation
import CoreLocation

struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let tts = TTSService()
    private let locationManager = CLLocationManager()

    /// 단계: 0=소개, 1=카메라, 2=위치, 3=마이크, 4=완료
    @State private var step = 0
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 전체 화면 탭 — 시각장애인은 아무데나 탭
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { handleTap() }
                .ignoresSafeArea()

            // 시각적 힌트 (보조 — 없어도 됨)
            VStack {
                Spacer()
                Image(systemName: stepIcon)
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.15))
                Spacer()
                Text("화면 어디든 탭하세요")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.12))
                    .padding(.bottom, 60)
            }
        }
        .onAppear { speakCurrentStep() }
        // VoiceOver 사용자: 전체를 하나의 버튼으로 인식
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stepAccessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { handleTap() }
    }

    // MARK: - 탭 처리

    private func handleTap() {
        guard !isProcessing else { return }
        switch step {
        case 0:
            // 소개 → 카메라 권한 안내
            step = 1
            speakCurrentStep()

        case 1:
            // 카메라 권한 요청
            isProcessing = true
            tts.speak("카메라 권한을 요청합니다", priority: .warning)
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async {
                    isProcessing = false
                    step = 2
                    speakCurrentStep()
                }
            }

        case 2:
            // 위치 권한 요청
            isProcessing = true
            tts.speak("위치 권한을 요청합니다", priority: .warning)
            locationManager.requestWhenInUseAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isProcessing = false
                step = 3
                speakCurrentStep()
            }

        case 3:
            // 마이크 권한 요청
            isProcessing = true
            tts.speak("마이크 권한을 요청합니다", priority: .warning)
            AVAudioApplication.requestRecordPermission { _ in
                DispatchQueue.main.async {
                    isProcessing = false
                    step = 4
                    speakCurrentStep()
                }
            }

        case 4:
            // 완료 → 앱 시작
            tts.speak("Guardian을 시작합니다", priority: .critical)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                hasCompletedOnboarding = true
            }

        default:
            break
        }
    }

    // MARK: - TTS 안내

    private func speakCurrentStep() {
        tts.speak(stepScript, priority: .warning)
    }

    private var stepScript: String {
        switch step {
        case 0:
            return "Guardian 앱입니다. 시각장애인을 위한 공간 인식 앱으로, 주변 장애물과 사람, 차량을 감지하고 음성으로 알려드립니다. 화면 어디든 탭하면 시작합니다."
        case 1:
            return "카메라 권한이 필요합니다. 간판 읽기와 출입구 찾기에 사용됩니다. 탭하면 권한을 요청합니다."
        case 2:
            return "위치 권한이 필요합니다. SOS 발송 시 보호자에게 현재 위치를 함께 전송합니다. 탭하면 권한을 요청합니다."
        case 3:
            return "마이크 권한이 필요합니다. 음성 안내를 위해 사용됩니다. 탭하면 권한을 요청합니다."
        case 4:
            return "모든 준비가 완료되었습니다. 탭하면 Guardian을 시작합니다."
        default:
            return ""
        }
    }

    private var stepIcon: String {
        switch step {
        case 0: return "eye.slash"
        case 1: return "camera"
        case 2: return "location"
        case 3: return "mic"
        case 4: return "checkmark.circle"
        default: return "circle"
        }
    }

    private var stepAccessibilityLabel: String { stepScript }
}
