//
//  AppTheme.swift
//  Silent Gym
//
//  Centralized design token system.
//  Pure-black OLED background + neon chartreuse accent for maximum gym-environment contrast.
//

import SwiftUI

// MARK: - Design Tokens

enum AppTheme {
    // Backgrounds
    static let background      = Color.black
    static let surface         = Color(white: 0.08)
    static let surfaceElevated = Color(white: 0.14)
    static let border          = Color(white: 0.20)

    /// Neon chartreuse — high-contrast on OLED black
    static let accent           = Color(red: 0.20, green: 0.98, blue: 0.44)
    static let accentForeground = Color.black

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.58)
    static let textTertiary  = Color(white: 0.34)

    // Semantic
    static let destructive = Color(red: 1.0, green: 0.27, blue: 0.27)
    static let warning     = Color(red: 1.0, green: 0.76, blue: 0.10)
    static let success     = accent

    // Shape
    static let cardRadius:   CGFloat = 18
    static let buttonRadius: CGFloat = 14
}

// MARK: - Button Styles

struct SGPrimaryButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isDestructive ? AppTheme.destructive : AppTheme.accent)
            .foregroundColor(isDestructive ? .white : AppTheme.accentForeground)
            .font(.body.bold())
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SGSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.surface)
            .foregroundColor(AppTheme.textPrimary)
            .font(.body.weight(.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply the app-wide card surface style
    func sgCard() -> some View {
        self
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    /// Neon-bordered card (highlights the active/focus card)
    func sgActiveCard() -> some View {
        self
            .background(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                    .stroke(AppTheme.accent.opacity(0.40), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}
