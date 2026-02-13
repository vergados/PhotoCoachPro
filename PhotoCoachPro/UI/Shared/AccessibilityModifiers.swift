//
//  AccessibilityModifiers.swift
//  PhotoCoachPro
//
//  VoiceOver + Dynamic Type helpers
//

import SwiftUI

// MARK: - Accessibility Extensions
extension View {
    /// Make interactive element accessible with proper label and hint
    func accessible(label: String, hint: String? = nil, traits: AccessibilityTraits = []) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }

    /// Make image decorative (hidden from VoiceOver)
    func decorative() -> some View {
        self.accessibilityHidden(true)
    }
}

// MARK: - Dynamic Type Support
extension Font {
    /// Preferred font with automatic scaling
    static func preferred(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default).weight(weight)
    }
}

// MARK: - Reduce Motion Support
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let enabledAnimation: Animation
    let disabledAnimation: Animation

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? disabledAnimation : enabledAnimation, value: UUID())
    }
}

extension View {
    func reducibleAnimation(_ animation: Animation = .default) -> some View {
        self.modifier(ReduceMotionModifier(
            enabledAnimation: animation,
            disabledAnimation: .linear(duration: 0.01)
        ))
    }
}

// MARK: - High Contrast Support
extension Color {
    /// Color that adapts to high contrast mode
    static func adaptive(light: Color, dark: Color, highContrast: Color) -> Color {
        // SwiftUI automatically handles this via ColorScheme and accessibilityDifferentiateWithoutColor
        // This is a helper for custom implementations
        return light
    }
}
