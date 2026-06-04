//
//  TTSService.swift
//  Guardian
//
//  Created by 정윤수 on 6/4/26.
//
import AVFoundation
import Combine
// ---------------------------------------------------------------
// TTSServiceProtocol
// BlindViewModel은 이 프로토콜만 바라봄
// 우선순위: 1. 카카오/네이버 길안내 > 2. 위험 알림 > 3. 일반 감지
// AVAudioSession 인터럽트 감지 → 외부 앱 TTS 중엔 대기
// ---------------------------------------------------------------
protocol TTSServiceProtocol {
     func speak(_ text: String, priority: TTSPriority)
    func stopAll()
}
@MainActor
enum TTSPriority: Int, Comparable {
    case general  = 0   // 장애물, 사물
       case warning  = 1   // 차량, 사람 접근
       case critical = 2   // 위험 (미래 확장용)
    
    static func < (lhs: TTSPriority, rhs: TTSPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
private  struct TTSItem {
    let text: String
    let priority: TTSPriority
}

final class TTSService: NSObject, TTSServiceProtocol {
    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [TTSItem] = []
    private var isExternalAudioActive = false
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSessionObserver()
    }
    // ---------------------------------------------------------------
    // speak
    // - warning/critical은 general 발화 중이면 인터럽트
    // - 외부 앱(카카오/네이버) TTS 중이면 큐에만 쌓고 대기
    // ---------------------------------------------------------------
    func speak(_ text: String, priority: TTSPriority) {
        let item = TTSItem(text: text, priority: priority)
        
        if isExternalAudioActive {
            enqueue(item)
            return
        }
        
        if synthesizer.isSpeaking {
            if priority > .general {
                synthesizer.stopSpeaking(at: .immediate)
                enqueue(item)
                playNext()
            } else {
                enqueue(item)
            }
            return
        }
        
        enqueue(item)
        playNext()
    }
    
    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        queue.removeAll()
    }
    // ---------------------------------------------------------------
    // AVAudioSession 인터럽트 감지
    // 카카오/네이버 길안내 시작 → isExternalAudioActive = true
    // 길안내 종료 → 큐에 쌓인 항목 재개
    // ---------------------------------------------------------------
    
    private func setupAudioSessionObserver()
    {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink{[weak self] notification in
                guard let self,
                      let userInfo = notification.userInfo,
                      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                switch type{
                case .began:
                    self.isExternalAudioActive = true
                    self.synthesizer.pauseSpeaking(at: .word)
                case .ended:
                    self.isExternalAudioActive = false
                    self.playNext()
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    private func enqueue(_ item: TTSItem) {
           // 우선순위 높은 것부터 앞으로
           let insertIndex = queue.firstIndex { $0.priority < item.priority } ?? queue.endIndex
           queue.insert(item, at: insertIndex)
       }

       private func playNext() {
           guard !isExternalAudioActive, !synthesizer.isSpeaking, let next = queue.first else { return }
           queue.removeFirst()

           let utterance = AVSpeechUtterance(string: next.text)
           utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR")
           utterance.rate = 0.55
           utterance.pitchMultiplier = 1.0
           synthesizer.speak(utterance)
       }
}
extension TTSService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        playNext()
    }
}
