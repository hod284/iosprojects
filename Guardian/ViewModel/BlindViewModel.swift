//
//  BlindViewModel.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
// 시각 장애인 모드 로직

import SwiftUI
// 데이터 흐름 관리 프레임 워크
// 값이 바뀌면 자동으로 알려주는 도구
import Combine

class BlindViewModel: ObservableObject {
    @Published var obtacleDetected: Bool = false
    @Published var detectionMessage: String = "안전합니다"
    @Published var isScanning: Bool = false
    
    // 라이더 서비스 주입
    // let은 상수
    // private let lidarService: LiDARService
    
    func startScanning() {
        isScanning = true
        //todo 감지 시작
        
    }
    
    func stopScanning() {
        isScanning = false
        obtacleDetected = false
        detectionMessage = "안전합니다"
    }
}


