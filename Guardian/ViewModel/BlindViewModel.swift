//
//  BlindViewModel.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
// BlindViewModel.swift
// Guardian Blind

import Foundation
import Combine

@MainActor
final class BlindViewModel: ObservableObject {

    // MARK: - Published (View에서 구독)
    @Published var detectedObjects: [DetectedObject] = []
    @Published var entranceCandidate: EntranceCandidate? = nil
    @Published var isSearchingEntrance: Bool = false
    @Published var settings: GuardianSettings = GuardianSettings.default

    // MARK: - Services
    private let lidarService: LiDARServiceProtocol
    private let ttsService: TTSServiceProtocol
    private let sosService: SOSService
    private let entranceService: EntranceDetectionServiceProtocol

    private var cancellables = Set<AnyCancellable>()

    // ---------------------------------------------------------------
    // 이전 프레임 객체 ID 추적
    // 이미 발화한 객체는 재진입 전까지 다시 말하지 않음
    // ---------------------------------------------------------------
    private var spokenObjectIDs = Set<UUID>()

    init(
        lidarService: LiDARServiceProtocol? = nil,
        ttsService: TTSServiceProtocol? = nil,
        sosService: SOSService? = nil,
        entranceService: EntranceDetectionServiceProtocol? = nil
    ) {
        self.lidarService = lidarService ?? LiDARService()
        self.ttsService = ttsService ?? TTSService()
        self.sosService = sosService ?? SOSService()
        self.entranceService = entranceService ?? EntranceDetectionService()

        loadSettings()
        bindServices()
    }

    // MARK: - 시작/종료

    func start() {
        lidarService.start()
        sosService.startMonitoring(settings: settings)
    }

    func stop() {
        lidarService.stop()
        sosService.stopMonitoring()
        entranceService.stop()
    }

    // MARK: - 출입구 찾기 버튼 탭

    func startEntranceSearch() {
        guard !isSearchingEntrance else { return }
        isSearchingEntrance = true
        entranceCandidate = nil
        entranceService.start()
        ttsService.speak("출입구를 찾고 있습니다", priority: .general)
    }

    // MARK: - Settings 저장/불러오기

    func saveSettings(_ newSettings: GuardianSettings) {
        settings = newSettings
        sosService.startMonitoring(settings: settings)
        if let data = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(data, forKey: "GuardianSettings")
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "GuardianSettings"),
              let saved = try? JSONDecoder().decode(GuardianSettings.self, from: data) else { return }
        settings = saved
    }

    // MARK: - 서비스 바인딩

    private func bindServices() {
        // LiDAR → 감지 객체 업데이트 + TTS
        lidarService.detectedObjectsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] objects in
                self?.handleDetectedObjects(objects)
            }
            .store(in: &cancellables)

        // 출입구 감지 결과
        entranceService.entranceFoundPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] candidate in
                self?.handleEntranceFound(candidate)
            }
            .store(in: &cancellables)
    }

    // MARK: - 감지 처리

    private func handleDetectedObjects(_ objects: [DetectedObject]) {
        detectedObjects = objects

        // EntranceDetectionService에 LiDAR 데이터 forwarding
        if isSearchingEntrance, let service = entranceService as? EntranceDetectionService{
            service.processLiDARObjects(objects)
        }

        // 민감도 기준 이하 + 새로 진입한 객체만 발화
        let threshold = settings.sensitivity.threshold
        let newObjects = objects.filter {
            $0.distance <= threshold && !spokenObjectIDs.contains($0.id)
        }

        // 우선순위 분류
        for object in newObjects {
            spokenObjectIDs.insert(object.id)
            let priority: TTSPriority = (object.type == .vechicle || object.type == .person) ? .warning : .general
            ttsService.speak(object.ttsDescription, priority: priority)
        }

        // 범위 벗어난 객체 ID 제거 → 재진입 시 다시 발화
        let currentIDs = Set(objects.map { $0.id })
        spokenObjectIDs = spokenObjectIDs.filter { currentIDs.contains($0) }
    }

    private func handleEntranceFound(_ candidate: EntranceCandidate) {
        entranceCandidate = candidate
        isSearchingEntrance = false
        ttsService.speak(candidate.ttsDescription, priority: .warning)
    }
}
