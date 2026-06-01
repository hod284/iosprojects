//
//  SafetyViewModel.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
// 여성 안적 모드 로직

import SwiftUI
import Combine
import CoreLocation

class SafetyViewModel: ObservableObject {
   
    @Published var isTracking : Bool = false
    @Published var currentLocation: CLLocationCoordinate2D? = nil
    @Published var sosTrriger: Bool = false
    
    // 나중에 서비스 주입
       // private let locationService: LocationService
       // private let emergencyService: EmergencyService
    
    func startTracking() {
        isTracking = true
     // todo : gps 위치추적 시작
    }
    func stopTracking() {
        isTracking = false
        
    }
    func toggleSOS() {
        sosTrriger = true
        // todo :112 전하 +보호자 sms
    }
    
}
