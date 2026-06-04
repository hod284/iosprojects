//
//  LiDARService.swift
//  Guardian
//
//  Created by 정윤수 on 6/3/26.
//

import ARKit
import Combine
import simd

// MARK: - LiDARServiceProtocol
// ---------------------------------------------------------------
// LiDARServiceProtocol
// 현재: LiDARService가 더미 타이머로 구현
// 추후: 실제 ARSession 구현으로 교체
// BlindViewModel은 이 프로토콜만 바라보기 때문에
// 교체해도 ViewModel 코드는 안 건드려도 됨
// ---------------------------------------------------------------

protocol LiDARServiceProtocol {
    var detectedObjectsPublisher: AnyPublisher<[DetectedObject], Never> { get }
    func start()
    func stop()
}

// MARK: - LiDARService

final class LiDARService: NSObject, LiDARServiceProtocol {

    // MARK: Publisher
    // ViewModel이 구독해서 감지 결과 받아감
    var detectedObjectsPublisher: AnyPublisher<[DetectedObject], Never> {
        detectedObjectsSubject.eraseToAnyPublisher()
    }
    private let detectedObjectsSubject = PassthroughSubject<[DetectedObject], Never>()

    // MARK: ARSession
    private let session = ARSession()
    private var isRunning = false

    // MARK: 더미 타이머 (실제 LiDAR 구현 전 테스트용)
    private var dummyTimer: AnyCancellable?

    // MARK: 이전 프레임 추적 (velocity 계산용)
    // key: UUID 문자열, value: 이전 위치
    private var previousPositions: [String: SIMD3<Float>] = [:]
    private var previousTimestamp: TimeInterval = 0

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // ---------------------------------------------------------------
           // TODO: 실제 LiDAR 구현 시 아래 주석 해제하고
           //       startDummyTimer() 제거
           //
           // 조건: LiDAR 지원 기기만 (iPhone 12 Pro 이상)
           // ---------------------------------------------------------------
           // guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
           //     print("LiDAR 미지원 기기")
           //     return
           // }
           // let config = ARWorldTrackingConfiguration()
           // config.sceneReconstruction = .meshWithClassification
           // config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
           // session.delegate = self
           // session.run(config)

        startDummyTimer()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        session.pause()
        dummyTimer?.cancel()
        dummyTimer = nil
        previousPositions.removeAll()
    }

    // MARK: - 더미 타이머
    // 실제 LiDAR 붙이기 전 UI/로직 테스트용
    // ---------------------------------------------------------------
    // 현재 상태: 더미 데이터 사용 중
    //
    // 발행 주기: 0.5초마다
    // 발행 내용: 아래 랜덤 조합
    //   - 물체 수:  1~3개
    //   - 타입:    person, vehicle, obstacle, object 중 랜덤
    //   - 거리:    0.5m ~ 5.0m 랜덤
    //   - 방향:    front, frontLeft, frontRight, left, right 중 랜덤
    //   - velocity: x, z 각각 -1.0 ~ 1.0 랜덤
    //
    // 교체 시점: LiDARService 실제 구현 완료 후
    // 교체 방법:
    //   1. startDummyTimer() 호출 제거
    //   2. start() 안에 주석 처리된 ARSession 코드 활성화
    //   3. ARSessionDelegate의 didUpdate frame 구현
    // ---------------------------------------------------------------
    private func startDummyTimer() {
        dummyTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.detectedObjectsSubject.send(Self.makeDummyObjects())
            }
    }

    private static func makeDummyObjects() -> [DetectedObject] {
        let types: [ObjectType] = [.person, .vechicle, .obstacle, .object]
        let directions: [Direction] = [.front, .frontLeft, .frontRight, .left, .right]

        return (0..<Int.random(in: 1...3)).map { _ in
            DetectedObject(
                type: types.randomElement()!,
                distance: Double.random(in: 0.5...5.0),
                direction: directions.randomElement()!,
                velocity: SIMD3<Float>(
                    Float.random(in: -1...1),
                    0,
                    Float.random(in: -1...1)
                )
            )
        }
    }
}

// MARK: - ARSessionDelegate
// 실제 LiDAR 구현 시 여기서 포인트 클라우드 처리

extension LiDARService: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // TODO: 실제 LiDAR 구현
        // let depthMap = frame.sceneDepth?.depthMap
        // let confidenceMap = frame.sceneDepth?.confidenceMap
        // processDepthMap(depthMap, confidence: confidenceMap, timestamp: frame.timestamp)
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // TODO: ARMeshAnchor 처리
        // anchors.compactMap { $0 as? ARMeshAnchor }.forEach { processAnchor($0) }
    }
}

// MARK: - 실제 LiDAR 처리 (TODO)

private extension LiDARService {

    /// 포인트 클라우드 → DetectedObject 변환
    /// 실제 LiDAR 구현 시 여기를 채움
    func processDepthMap(_ depthMap: CVPixelBuffer?, timestamp: TimeInterval) {
        guard let depthMap else { return }

        // 1. depth map에서 포인트 추출
        // 2. 클러스터링으로 물체 묶기
        // 3. 각 클러스터 → ObjectType 분류
        // 4. 거리 + 방향 계산
        // 5. velocity 계산 (이전 프레임과 비교)
        // 6. detectedObjectsSubject.send(objects)
    }

    /// 3D 좌표 → 거리 계산
    func calculateDistance(x: Float, z: Float) -> Double {
        Double(sqrt(x * x + z * z))
    }

    /// 이전 프레임과 비교해서 이동 벡터 계산
    func calculateVelocity(
        id: String,
        currentPosition: SIMD3<Float>,
        timestamp: TimeInterval
    ) -> SIMD3<Float>? {
        guard let previous = previousPositions[id],
              previousTimestamp > 0 else {
            previousPositions[id] = currentPosition
            previousTimestamp = timestamp
            return nil
        }

        let dt = Float(timestamp - previousTimestamp)
        guard dt > 0 else { return nil }

        let velocity = (currentPosition - previous) / dt
        previousPositions[id] = currentPosition
        previousTimestamp = timestamp

        return velocity
    }
}
