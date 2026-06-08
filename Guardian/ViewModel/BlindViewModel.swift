// BlindViewModel.swift
// Guardian Blind

import Foundation
import Combine

@MainActor
final class BlindViewModel: ObservableObject {

    // MARK: - Published
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
    private var spokenObjectIDs = Set<UUID>()

    // MARK: - Init
    // @MainActor 파라미터 기본값에서 직접 인스턴스 생성 불가 → nil로 받고 내부에서 생성
    init(
        lidarService: LiDARServiceProtocol? = nil,
        ttsService: TTSServiceProtocol? = nil,
        sosService: SOSService? = nil,
        entranceService: EntranceDetectionServiceProtocol? = nil
    ) {
        self.lidarService    = lidarService    ?? LiDARService()
        self.ttsService      = ttsService      ?? TTSService()
        self.sosService      = sosService      ?? SOSService()
        self.entranceService = entranceService ?? EntranceDetectionService()

        loadSettings()
        bindServices()
    }

    // MARK: - 생명주기

    func start() {
        lidarService.start()
        sosService.startMonitoring(settings: settings)
    }

    func stop() {
        lidarService.stop()
        sosService.stopMonitoring()
        entranceService.stop()
    }

    // MARK: - 출입구 찾기

    func startEntranceSearch() {
        guard !isSearchingEntrance else { return }
        isSearchingEntrance = true
        entranceCandidate = nil
        entranceService.start()
        ttsService.speak("출입구를 찾고 있습니다", priority: .general)
    }

    // MARK: - 설정 저장/불러오기

    func saveSettings(_ newSettings: GuardianSettings) {
        settings = newSettings
        sosService.startMonitoring(settings: settings)
        if let data = try? JSONEncoder().encode(newSettings) {
            UserDefaults.standard.set(data, forKey: "GuardianSettings")
        }
    }

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "GuardianSettings"),
              let saved = try? JSONDecoder().decode(GuardianSettings.self, from: data)
        else { return }
        settings = saved
    }

    // MARK: - TTS 헬퍼 (View에서 직접 호출용)

    /// 앱 시작 시 음성 안내
    func announceStart() {
        ttsService.speak(
            "Guardian 시작됩니다. 주변 장애물을 감지합니다. 화면 왼쪽 아래를 탭하면 읽어줘, 오른쪽 아래를 탭하면 출입구 찾기입니다.",
            priority: .warning
        )
    }

    /// 외부(View)에서 직접 TTS 호출
    func speak(_ text: String, priority: TTSPriority = .general) {
        ttsService.speak(text, priority: priority)
    }

    // MARK: - 서비스 바인딩

    private func bindServices() {
        lidarService.detectedObjectsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] objects in
                self?.handleDetectedObjects(objects)
            }
            .store(in: &cancellables)

        entranceService.entranceFoundPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] candidate in
                self?.handleEntranceFound(candidate)
            }
            .store(in: &cancellables)
    }

    private func handleDetectedObjects(_ objects: [DetectedObject]) {
        detectedObjects = objects

        if isSearchingEntrance,
           let service = entranceService as? EntranceDetectionService {
            service.processLiDARObjects(objects)
        }

        let threshold = settings.sensitivity.threshold
        let newObjects = objects.filter {
            $0.distance <= threshold && !spokenObjectIDs.contains($0.id)
        }

        for object in newObjects {
            spokenObjectIDs.insert(object.id)
            let priority: TTSPriority = (object.type == .vehicle || object.type == .person)
                ? .warning : .general
            ttsService.speak(object.ttsDescription, priority: priority)
        }

        let currentIDs = Set(objects.map { $0.id })
        spokenObjectIDs = spokenObjectIDs.filter { currentIDs.contains($0) }
    }

    private func handleEntranceFound(_ candidate: EntranceCandidate) {
        entranceCandidate = candidate
        isSearchingEntrance = false
        ttsService.speak(candidate.ttsDescription, priority: .warning)
    }
}
