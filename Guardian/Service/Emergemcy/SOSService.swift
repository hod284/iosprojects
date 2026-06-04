//
//  SOSService.swift
//  Guardian
//
//  Created by 정윤수 on 6/4/26.
//

// SOSService.swift
// Guardian Blind

import AVFoundation
import CoreLocation
import MessageUI
import Combine

// ---------------------------------------------------------------
// SOSServiceProtocol
// 볼륨 버튼 3번 연속 감지 → 보호자에게 위치 포함 SMS 자동 발송
// 전화 기능 없음 (iOS 제약상 백그라운드 자동 발신 불가)
// 112 자동 신고 → TODO (나중에 추가 예정)
// ---------------------------------------------------------------
protocol SOSServiceProtocol {
    func startMonitoring(settings: GuardianSettings)
    func stopMonitoring()
}

protocol SOSServiceDelegate: AnyObject {
    func sosService(_ service: SOSService, presentSMSController controller: MFMessageComposeViewController)
}

final class SOSService: NSObject, SOSServiceProtocol {

    weak var delegate: SOSServiceDelegate?

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var settings: GuardianSettings?

    // 볼륨 감지
    private var volumePressTimestamps: [Date] = []
    private var audioSession = AVAudioSession.sharedInstance()
    private var volumeObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    // MARK: - 모니터링 시작/종료

    func startMonitoring(settings: GuardianSettings) {
        self.settings = settings
        setupVolumeMonitoring()
        startLocationUpdates()
    }

    func stopMonitoring() {
        volumeObserver?.invalidate()
        volumeObserver = nil
        locationManager.stopUpdatingLocation()
    }

    // MARK: - 볼륨 버튼 감지
    // ---------------------------------------------------------------
    // AVAudioSession outputVolume KVO로 볼륨 변화 감지
    // 1초 이내 3번 변화 → SOS 트리거
    // 볼륨 올리든 내리든 상관없이 누른 횟수만 카운트
    // ---------------------------------------------------------------
    private func setupVolumeMonitoring() {
        try? audioSession.setCategory(.playback, options: .mixWithOthers)
        try? audioSession.setActive(true)

        volumeObserver = audioSession.observe(\.outputVolume, options: [.new]) { [weak self] _, _ in
            self?.handleVolumePress()
        }
    }

    private func handleVolumePress() {
        let now = Date()
        volumePressTimestamps.append(now)

        // 1초 이전 기록 제거
        volumePressTimestamps = volumePressTimestamps.filter {
            now.timeIntervalSince($0) <= 1.0
        }

        if volumePressTimestamps.count >= 3 {
            volumePressTimestamps.removeAll()
            triggerSOS()
        }
    }

    // MARK: - SOS 트리거

    private func triggerSOS() {
        guard let settings, !settings.guardianPhone.isEmpty else { return }
        sendSMS(location: currentLocation)
    }

    // MARK: - 위치 추적

    private func startLocationUpdates() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
    }

    // MARK: - SMS 발송

    private func sendSMS(location: CLLocation?) {
        guard let settings,
              MFMessageComposeViewController.canSendText() else { return }

        let vc = MFMessageComposeViewController()
        vc.recipients = [settings.guardianPhone]
        vc.body = buildSMSBody(guardianName: settings.guardianName, location: location)
        vc.messageComposeDelegate = self

        delegate?.sosService(self, presentSMSController: vc)
    }

    private func buildSMSBody(guardianName: String, location: CLLocation?) -> String {
        var lines: [String] = [
            "[\(guardianName)님께 SOS]",
            "Guardian 앱 사용자가 도움을 요청했습니다.",
        ]

        if let loc = location {
            let lat = String(format: "%.5f", loc.coordinate.latitude)
            let lon = String(format: "%.5f", loc.coordinate.longitude)
            lines.append("현재 위치: https://maps.apple.com/?q=\(lat),\(lon)")
        } else {
            lines.append("(위치 정보 없음)")
        }

        lines.append("발송 시각: \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))")
        return lines.joined(separator: "\n")
    }
}

// MARK: - CLLocationManagerDelegate

extension SOSService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 실패해도 SMS는 위치 없이 발송
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - MFMessageComposeViewControllerDelegate

extension SOSService: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
}
