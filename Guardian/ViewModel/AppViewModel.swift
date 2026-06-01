//
//  AppViewModel.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
// 앱 전체 상태 관리

import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var selectedMode : AppMode? = nil
    @Published var isOnboarded: Bool = false
}

