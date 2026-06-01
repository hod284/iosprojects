//
//  User.swift
//  Guardian
//
//  Created by 정윤수 on 6/1/26.
// 사용자 데이터 모델
import Foundation

struct User
{
    var name : String
    var selectedmodel : AppMode
   var emergencyContact : EmergencyContact
}

struct EmergencyContact
{
    var name : String
    var phoneNumber : String
}
