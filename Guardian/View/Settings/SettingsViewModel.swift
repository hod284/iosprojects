//
//  SettingsViewModel.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
//설정화면 로직

import SwiftUI
import Combine

class SettingsViewModel: ObservableObject {
    @Published var emergencyContacts: [EmergencyContact] = []
    @Published var userName: String = ""

    func addContact(_ contact: EmergencyContact) {
        emergencyContacts.append(contact)
    }

    func removeContact(at offsets: IndexSet) {
        emergencyContacts.remove(atOffsets: offsets)
    }
}
