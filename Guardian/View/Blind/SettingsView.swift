// SettingsView.swift
// Guardian Blind
//
// 보호자 또는 타인이 도와주는 설정 화면.
// 항목 선택 시 TTS로 내용을 읽어줘서
// 시각장애인도 설정 과정을 음성으로 확인할 수 있음.

import SwiftUI

struct SettingsView: View {

    @ObservedObject var viewModel: BlindViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: GuardianSettings = .default
    @State private var showSaveConfirm = false

    private let tts = TTSService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 28) {
                        sensitivitySection
                        ttsRateSection
                        guardianSection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                }

                saveButton
            }
        }
        .onAppear {
            draft = viewModel.settings
            // 설정 화면 진입 시 TTS 안내
            tts.speak("설정 화면입니다. 감지 민감도, 음성 속도, 보호자 연락처를 설정할 수 있습니다.", priority: .warning)
        }
        .alert("저장되었습니다", isPresented: $showSaveConfirm) {
            Button("확인") { dismiss() }
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            Text("설정")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                tts.speak("설정을 닫습니다")
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.4))
            }
            .accessibilityLabel("설정 닫기")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - 감지 민감도

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("감지 민감도")

            ForEach(Sensitivity.allCases, id: \.self) { level in
                Button(action: {
                    draft.sensitivity = level
                    // 선택 시 TTS로 확인
                    tts.speak("감지 민감도 \(level.displayName) 선택됨. \(level.ttsDescription)", priority: .warning)
                }) {
                    HStack(spacing: 14) {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                            .background(
                                Circle().fill(draft.sensitivity == level ? Color.white : Color.clear)
                            )
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(level.displayName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text(level.ttsDescription)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.55))
                        }

                        Spacer()
                    }
                    .padding(16)
                    .background(draft.sensitivity == level ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                    .cornerRadius(14)
                }
                .accessibilityLabel("\(level.displayName), \(level.ttsDescription)\(draft.sensitivity == level ? ", 현재 선택됨" : "")")
                .accessibilityAddTraits(draft.sensitivity == level ? [.isSelected] : [])
            }
        }
    }

    // MARK: - TTS 속도

    private var ttsRateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("음성 안내 속도")

            VStack(spacing: 10) {
                Slider(
                    value: $draft.ttsRate,
                    in: 0.3...0.8,
                    step: 0.05,
                    onEditingChanged: { editing in
                        if !editing {
                            let percent = Int(draft.ttsRate * 100)
                            tts.speak("음성 속도 \(percent)퍼센트로 설정됨", priority: .warning)
                        }
                    }
                )
                .accentColor(.white)
                .accessibilityLabel("음성 안내 속도")
                .accessibilityValue("\(Int(draft.ttsRate * 100))퍼센트")

                HStack {
                    Text("느리게")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text("\(Int(draft.ttsRate * 100))%")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Text("빠르게")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
        }
    }

    // MARK: - 보호자 연락처

    private var guardianSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("보호자 연락처 (SOS)")

            VStack(spacing: 12) {
                settingsTextField(
                    label: "이름",
                    placeholder: "예: 홍길동",
                    text: $draft.guardianName,
                    keyboardType: .default,
                    accessibilityLabel: "보호자 이름"
                )

                settingsTextField(
                    label: "전화번호",
                    placeholder: "예: 010-1234-5678",
                    text: $draft.guardianPhone,
                    keyboardType: .phonePad,
                    accessibilityLabel: "보호자 전화번호"
                )
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)

            Text("볼륨 버튼 3번 연속 → 위치 포함 문자 자동 발송")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 4)
        }
    }

    // MARK: - 저장 버튼

    private var saveButton: some View {
        Button(action: save) {
            Text("저장")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.white)
                .cornerRadius(16)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .accessibilityLabel("설정 저장")
    }

    // MARK: - 공통 컴포넌트

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white.opacity(0.45))
            .accessibilityAddTraits(.isHeader)
    }

    private func settingsTextField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        accessibilityLabel: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
            TextField(placeholder, text: text)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    // MARK: - 저장 액션

    private func save() {
        viewModel.saveSettings(draft)
        let name = draft.guardianName.isEmpty ? "미설정" : draft.guardianName
        tts.speak("설정이 저장되었습니다. 보호자 \(name), 감지 민감도 \(draft.sensitivity.displayName)", priority: .warning)
        showSaveConfirm = true
    }
}

// MARK: - Sensitivity 확장

extension Sensitivity {
    var displayName: String {
        switch self {
        case .low:    return "낮음"
        case .medium: return "보통"
        case .high:   return "높음"
        }
    }

    var ttsDescription: String {
        switch self {
        case .low:    return "3미터 이내 장애물만 알림"
        case .medium: return "5미터 이내 장애물 알림"
        case .high:   return "7미터 이내 장애물 모두 알림"
        }
    }
}
