//
//  AppTab.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/20.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case routines = "计划"
    case records = "记录"
    case train = "训练"
    case settings = "设置"
    
    var icon: String {
        switch self {
        case .routines:
            return "list.bullet"
        case .records:
            return "clock.fill"
        case .train:
            return "dumbbell.fill"
        case .settings:
            return "gearshape.fill"
        }
    }
}
