
import ARKit
import Vision
import Combine

// ---------------------------------------------------------------
// EntranceDetectionServiceProtocol
// [출입구 찾기] 버튼 탭 → start()
// 결과 나오면 → entranceFoundPublisher로 방향 발행 → TTS
// 결과 나오면 카메라 OFF, LiDAR 상시 복귀
// ---------------------------------------------------------------
protocol EntranceDetectionServiceProtocol {
    var entranceFoundPublisher: AnyPublisher<EntranceCandidate, Never> { get }
    func start()
    func stop()
}

final class EntranceDetectionService: NSObject, EntranceDetectionServiceProtocol {

    var entranceFoundPublisher: AnyPublisher<EntranceCandidate, Never> {
        entranceFoundSubject.eraseToAnyPublisher()
    }
    private let entranceFoundSubject = PassthroughSubject<EntranceCandidate, Never>()

    // LiDAR 쪽 — 사람 소실 패턴
    private var candidateMap: [String: EntranceCandidate] = [:]   // key: Direction.rawValue
    private var trackedPersons: [String: (direction: Direction, lastSeen: Date)] = [:]

    // YOLO 쪽 — 카메라 문 감지
    private var captureSession: AVCaptureSession?
    private var visionRequest: VNCoreMLRequest?

    private var isRunning = false
    private var hasFoundEntrance = false

    // ---------------------------------------------------------------
    // TODO: CoreML 모델 교체 시 아래 loadYOLOModel() 구현
    // 현재: Vision request nil → YOLO 경로 비활성
    // 교체 방법: YOLOv8 → CoreML 변환 후 .mlpackage 번들에 추가
    //           guard let model = try? VNCoreMLModel(for: YOLOv8(configuration: .init()).model)
    // ---------------------------------------------------------------
    override init() {
        super.init()
        loadYOLOModel()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        hasFoundEntrance = false
        candidateMap.removeAll()
        trackedPersons.removeAll()
        startCamera()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopCamera()
        candidateMap.removeAll()
        trackedPersons.removeAll()
    }

    // ---------------------------------------------------------------
    // LiDAR 사람 소실 패턴 처리
    // BlindViewModel이 LiDARService로부터 받은 [DetectedObject]를
    // 이쪽으로 forwarding해서 호출
    // ---------------------------------------------------------------
    func processLiDARObjects(_ objects: [DetectedObject]) {
        guard isRunning, !hasFoundEntrance else { return }

        let now = Date()
        let currentPersons = objects.filter { $0.type == .person && $0.distance < 3.0 }

        // 현재 프레임에 있는 사람 ID 목록
        let currentIDs = Set(currentPersons.map { $0.id.uuidString })

        // 이전 프레임에 있었는데 지금 없는 사람 → 소실 감지
        for (id, tracked) in trackedPersons {
            guard !currentIDs.contains(id) else { continue }

            let elapsed = now.timeIntervalSince(tracked.lastSeen)
            // 0.3초~2초 사이에 소실 → 자연스러운 통과가 아닌 출입구 소실로 판단
            if elapsed > 0.3 && elapsed < 2.0 {
                updateCandidate(direction: tracked.direction, type: .disappear)
            }
        }

        // 이전 프레임에 없었는데 지금 있는 사람 → 출현 감지
        for person in currentPersons {
            let id = person.id.uuidString
            if trackedPersons[id] == nil {
                updateCandidate(direction: person.direction, type: .appear)
            }
            trackedPersons[id] = (direction: person.direction, lastSeen: now)
        }

        // 오래된 추적 제거 (2초 이상 미감지)
        trackedPersons = trackedPersons.filter { now.timeIntervalSince($0.value.lastSeen) < 2.0 }
    }

    // MARK: - Candidate 업데이트

    private enum PatternType { case disappear, appear }

    private func updateCandidate(direction: Direction, type: PatternType) {
        let key = direction.rawValue
        var candidate = candidateMap[key] ?? EntranceCandidate(
            direction: direction,
            disappearCount: 0,
            appearCount: 0,
            firstDetectedAt: Date(),
            lastUpdatedAt: Date()
        )

        switch type {
        case .disappear: candidate.disappearCount += 1
        case .appear:    candidate.appearCount += 1
        }
        candidate.lastUpdatedAt = Date()
        candidateMap[key] = candidate

        if candidate.isConfirmed {
            notifyEntranceFound(candidate)
        }
    }

    private func notifyEntranceFound(_ candidate: EntranceCandidate) {
        guard !hasFoundEntrance else { return }
        hasFoundEntrance = true
        entranceFoundSubject.send(candidate)
        stop() // 결과 나오면 카메라 OFF
    }

    // MARK: - YOLO 카메라

    private func loadYOLOModel() {
        // TODO: CoreML 모델 로드
        // guard let model = try? VNCoreMLModel(for: YOLOv8(configuration: .init()).model) else { return }
        // visionRequest = VNCoreMLRequest(model: model) { [weak self] request, _ in
        //     self?.handleYOLOResults(request.results)
        // }
        // visionRequest?.imageCropAndScaleOption = .scaleFill
    }

    private func startCamera() {
        guard visionRequest != nil else { return } // 모델 없으면 카메라 안 켬
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "entrance.camera"))

        session.addInput(input)
        session.addOutput(output)
        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
    }

    private func handleYOLOResults(_ results: [Any]?) {
        guard !hasFoundEntrance,
              let observations = results as? [VNRecognizedObjectObservation],
              let door = observations.first(where: {
                  $0.labels.first?.identifier.lowercased().contains("door") == true &&
                  $0.confidence > 0.6
              }) else { return }

        // 감지된 문의 화면 위치로 방향 계산
        let centerX = door.boundingBox.midX - 0.5  // -0.5 ~ 0.5
        let direction: Direction = centerX < -0.2 ? .frontLeft :
                                   centerX >  0.2 ? .frontRight : .front

        let candidate = EntranceCandidate(
            direction: direction,
            disappearCount: 0,
            appearCount: 0,
            firstDetectedAt: Date(),
            lastUpdatedAt: Date()
        )
        notifyEntranceFound(candidate)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension EntranceDetectionService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let request = visionRequest,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
