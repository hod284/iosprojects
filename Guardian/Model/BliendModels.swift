//
//  Untitled.swift
//  Guardian
//
//  Created by 정윤수 on 6/3/26.
//
import Foundation
import simd

// MARK:  object type
enum ObjectType: String, CaseIterable {
    case person = "사람"
    case vechicle = "차"
    case obstacle = "장애물"
    case object = "사물"
    // door는 LiDAR 상시 감지 대상이 아님
      // → EntranceDetectionService에서 별도 처리
      // → 사람 이동 방향 추적 + 버튼 탭 시 카메라 보조
}
// MARK:  direction
enum Direction: String {
    case front      = "전방"
       case frontLeft  = "전방 왼쪽"
       case frontRight = "전방 오른쪽"
       case left       = "왼쪽"
       case right      = "오른쪽"
       case rearLeft   = "후방 왼쪽"
       case rearRight  = "후방 오른쪽"
       case behind     = "후방"
    
    /// ARKit 좌표 → 8방향 변환
       /// ARKit 기준: -z = 전방, +x = 오른쪽
       static func from(x: Float, z: Float) -> Direction {
           let angle = atan2(x, -z) * (180 / .pi)

           switch angle {
           case -22.5..<22.5:          return .front
           case 22.5..<67.5:           return .frontRight
           case 67.5..<112.5:          return .right
           case 112.5..<157.5:         return .rearRight
           case -67.5..<(-22.5):       return .frontLeft
           case -112.5..<(-67.5):      return .left
           case -157.5..<(-112.5):     return .rearLeft
           default:                    return .behind
           }
       }
}
// MARK:  sensitivitylevel
enum SensitivityLevel: String, CaseIterable,Codable {
   case low    = "낮음"
   case medium = "보통"
   case high   = "높음"

        /// 감지 거리 기준 (미터)
        var threshold: Double {
            switch self {
            case .low:    return 1.0
            case .medium: return 3.0
            case .high:   return 5.0
            }
        }

        var description: String {
            switch self {
            case .low:    return "1m 이내만 감지"
            case .medium: return "3m 이내 감지"
            case .high:   return "5m 이내 감지"
            }
        }
}

// MARK: dectedobject
// Identifiable은 각 항목이 고유한 id를 가진다고 Swift에게 알려주는 프로토콜이에요.Identifiable은 각 항목이 고유한 id를 가진다고 Swift에게 알려주는 프로토콜
struct DetectedObject: Identifiable,Equatable {
        let id: UUID // 내가 직접 지정하는거 나중에 사람인식 확인할때 중복 방지하기 위해 이용
        let type: ObjectType
        let distance: Double        // 미터
        let direction: Direction
        let detectedAt: Date
        var velocity: SIMD3<Float>? // 이동 방향 + 속도 (출입구 추론용)

        init(
            id: UUID = UUID(),
            type: ObjectType,
            distance: Double,
            direction: Direction,
            detectedAt: Date = Date(),
            velocity: SIMD3<Float>? = nil
        ) {
            self.id = id
            self.type = type
            self.distance = distance
            self.direction = direction
            self.detectedAt = detectedAt
            self.velocity = velocity
        }

        /// TTS 발화 문장
        /// 예: "전방 1.5미터 사람", "왼쪽 3.0미터 차량"
        var ttsDescription: String {
            let dist = String(format: "%.1f", distance)
            return "\(direction.rawValue) \(dist)미터 \(type.rawValue)"
        }

        static func == (lhs: DetectedObject, rhs: DetectedObject) -> Bool {
            lhs.id == rhs.id
        }
}

// entrancecandudate
// 출입구 추론 결과 - 사람 소실/ 출현 패턴누적
struct EntranceCandidate {
    let direction: Direction
    var disappearCount: Int  // 이 방향으로 사라진 횟수
    var appearCount: Int     // 이 방향에서 나타난 횟수
    let firstDetectedAt: Date
    var lastUpdatedAt: Date

    /// 2회 이상 패턴 반복 시 출입구로 확정
    var isConfirmed: Bool {
        (disappearCount + appearCount) >= 2
    }

    /// TTS 발화 문장
    var ttsDescription: String {
        "\(direction.rawValue) 방향에 출입구로 추정되는 곳이 있습니다"
    }
}

// MARK: GuardianSettings
// Codable 데이터 저장 및 불러오는 프로토콜 한번에 저장할수 있어서 이렇게 자주씀
struct GuardianSettings: Codable {
    var sensitivity: SensitivityLevel
    var ttsSpeed: Float         // 0.3 ~ 0.6 (AVSpeechUtteranceDefaultSpeechRate 기준)
    var guardianName: String
    var guardianPhone: String
    var isOnboardingDone: Bool

    static var `default`: GuardianSettings {
        GuardianSettings(
            sensitivity: .medium,
            ttsSpeed: 0.5,
            guardianName: "",
            guardianPhone: "",
            isOnboardingDone: false
        )
    }
}
