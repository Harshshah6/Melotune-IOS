import SwiftUI

/// Visual language for the iOS app: native iOS 26 Liquid Glass surfaces on top of the
/// platform's adaptive colours, replacing Android's Material components.
enum Theme {
    /// Accent colour, driven by the selected palette (mirrors Android `ThemeManager`
    /// palettes: emerald, ocean, purple, crimson, amber). Reading `Preferences` inside
    /// this computed property means SwiftUI re-renders views that use it when the
    /// palette changes.
    static var accent: Color {
        paletteColors[Preferences.shared.themePalette] ?? paletteColors["emerald"]!
    }

    static let paletteOrder = ["emerald", "ocean", "purple", "crimson", "amber"]

    static let paletteColors: [String: Color] = [
        "emerald": Color(red: 0.204, green: 0.780, blue: 0.345),
        "ocean": Color(red: 0.120, green: 0.550, blue: 0.900),
        "purple": Color(red: 0.550, green: 0.350, blue: 0.850),
        "crimson": Color(red: 0.850, green: 0.250, blue: 0.350),
        "amber": Color(red: 0.950, green: 0.650, blue: 0.200)
    ]

    static func paletteLabel(_ key: String) -> String {
        switch key {
        case "ocean": return "Ocean Blue"
        case "purple": return "Sunset Purple"
        case "crimson": return "Crimson Rose"
        case "amber": return "Amber Gold"
        default: return "Emerald"
        }
    }

    static let corner: CGFloat = 18
    static let cornerSmall: CGFloat = 12
}

/// Applies a Liquid Glass surface on iOS 26+, falling back to a thin material on earlier
/// systems. This is the single place platform chrome is decided.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(resolvedGlass(), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }

    @available(iOS 26.0, *)
    private func resolvedGlass() -> Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

extension View {
    func glassSurface<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive))
    }

    /// Pins the persistent mini player to the bottom of this scroll container so content
    /// is never hidden underneath it. Applied per scroll view for reliable insets on
    /// every iOS version.
    func withMiniPlayer() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerView()
        }
    }
}

/// A rounded Liquid Glass container used for cards, bars and panels.
struct GlassPanel<Content: View>: View {
    var cornerRadius: CGFloat = Theme.corner
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .glassSurface(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
    }
}

/// Primary action button that adopts the native glass button style where available.
struct GlassButton<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) { label() }
                .buttonStyle(.glass)
        } else {
            Button(action: action) { label() }
                .buttonStyle(.bordered)
        }
    }
}
