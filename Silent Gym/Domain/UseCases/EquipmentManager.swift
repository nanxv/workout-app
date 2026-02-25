//
//  EquipmentManager.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/02/25.
//
//  Manages the user's Home Gym equipment inventory and provides
//  exercise substitution suggestions when equipment is unavailable.
//

import Foundation
import Combine

// MARK: - GymEquipment

/// All recognized equipment types. `rawValue` is the Chinese display name
/// and is also stored in `Exercise.equipmentRequirements`.
public enum GymEquipment: String, CaseIterable, Codable, Identifiable {
    case barbell         = "杠铃"
    case adjustableDumbbells = "可调节哑铃"
    case fixedDumbbells  = "固定哑铃"
    case pullupBar       = "引体向上杆"
    case bench           = "卧推凳"
    case squatRack       = "深蹲架"
    case cableMachine    = "龙门架"
    case resistanceBand  = "弹力带"
    case dippingBars     = "双杠"
    case kettlebell      = "壶铃"

    public var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .barbell:              return "scalemass.fill"
        case .adjustableDumbbells,
             .fixedDumbbells:      return "dumbbell.fill"
        case .pullupBar:            return "figure.gymnastics"
        case .bench:                return "rectangle.fill"
        case .squatRack:            return "building.2.fill"
        case .cableMachine:         return "cable.connector"
        case .resistanceBand:       return "link.circle.fill"
        case .dippingBars:          return "figure.strengthtraining.traditional"
        case .kettlebell:           return "circle.fill"
        }
    }

    /// Canonical equipment names that map to this case (for matching exercise requirements).
    var aliases: [String] {
        [rawValue]
    }
}

// MARK: - Substitution Map

/// A rule mapping a required equipment type to a fallback exercise name.
struct SubstitutionRule {
    /// Keyword found in the original exercise name (case-insensitive).
    let exerciseKeyword: String
    /// Required equipment that is missing.
    let missingEquipment: GymEquipment
    /// Suggested replacement exercise.
    let substitute: String
}

private let substitutionRules: [SubstitutionRule] = [
    // Cable / pulley → resistance band or bodyweight
    SubstitutionRule(exerciseKeyword: "高位下拉",    missingEquipment: .cableMachine,    substitute: "引体向上"),
    SubstitutionRule(exerciseKeyword: "绳索",        missingEquipment: .cableMachine,    substitute: "弹力带代替"),
    SubstitutionRule(exerciseKeyword: "cable",       missingEquipment: .cableMachine,    substitute: "弹力带代替"),
    // Barbell exercises → dumbbell / bodyweight alternatives
    SubstitutionRule(exerciseKeyword: "杠铃卧推",    missingEquipment: .barbell,         substitute: "哑铃卧推 或 俯卧撑"),
    SubstitutionRule(exerciseKeyword: "深蹲",        missingEquipment: .squatRack,       substitute: "哑铃深蹲 或 保加利亚分腿蹲"),
    SubstitutionRule(exerciseKeyword: "硬拉",        missingEquipment: .barbell,         substitute: "哑铃罗马尼亚硬拉"),
    SubstitutionRule(exerciseKeyword: "杠铃划船",    missingEquipment: .barbell,         substitute: "哑铃单臂划船"),
    SubstitutionRule(exerciseKeyword: "bench",       missingEquipment: .bench,           substitute: "地面哑铃卧推 或 俯卧撑"),
    // Dumbbell → resistance band
    SubstitutionRule(exerciseKeyword: "哑铃",        missingEquipment: .adjustableDumbbells, substitute: "弹力带代替"),
    // Dipping bars → bench dip
    SubstitutionRule(exerciseKeyword: "双杠",        missingEquipment: .dippingBars,     substitute: "凳上臂屈伸"),
    // Pull-up bar
    SubstitutionRule(exerciseKeyword: "引体",        missingEquipment: .pullupBar,       substitute: "弹力带辅助 或 坐姿划船"),
]

// MARK: - EquipmentManager

/// Persists the user's Home Gym equipment checklist and exposes helpers
/// that `SessionCoordinator` uses to filter or substitute exercises.
@MainActor
final class EquipmentManager: ObservableObject {

    static let shared = EquipmentManager()

    @Published var availableEquipment: Set<GymEquipment>

    private let storageKey = "silentGym.availableEquipment.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: "silentGym.availableEquipment.v1"),
           let decoded = try? JSONDecoder().decode([GymEquipment].self, from: data) {
            availableEquipment = Set(decoded)
        } else {
            // Default: user has all common home-gym equipment
            availableEquipment = Set(GymEquipment.allCases)
        }
    }

    // MARK: - Public API

    /// Toggles the availability of a piece of equipment.
    func toggle(_ equipment: GymEquipment) {
        if availableEquipment.contains(equipment) {
            availableEquipment.remove(equipment)
        } else {
            availableEquipment.insert(equipment)
        }
        persist()
    }

    /// Returns `true` when the exercise can be performed with current equipment.
    /// An exercise with no requirements is always doable (bodyweight).
    func canPerform(_ exercise: Exercise) -> Bool {
        guard !exercise.equipmentRequirements.isEmpty else { return true }
        return exercise.equipmentRequirements.allSatisfy { req in
            availableEquipment.contains(where: { $0.rawValue == req })
        }
    }

    /// Returns a suggested substitute exercise name, or `nil` if no rule applies.
    func suggestSubstitute(for exercise: Exercise) -> String? {
        for rule in substitutionRules {
            let nameMatches = exercise.name.localizedCaseInsensitiveContains(rule.exerciseKeyword)
            let equipmentMissing = !availableEquipment.contains(rule.missingEquipment)
            if nameMatches && equipmentMissing {
                return rule.substitute
            }
        }
        return nil
    }

    /// Returns `(canPerform, substituteHint)` for every exercise in a list.
    func assess(
        _ exercises: [Exercise]
    ) -> [(exercise: Exercise, canPerform: Bool, substitute: String?)] {
        exercises.map { ex in
            let ok = canPerform(ex)
            let sub = ok ? nil : suggestSubstitute(for: ex)
            return (ex, ok, sub)
        }
    }

    // MARK: - Persistence

    private func persist() {
        let data = try? JSONEncoder().encode(Array(availableEquipment))
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
