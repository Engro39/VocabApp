import SwiftUI

extension Color {
    static let setColors: [Color] = [
        Color(hex: "#e8c547"),
        Color(hex: "#ff6b6b"),
        Color(hex: "#4ecdc4"),
        Color(hex: "#a78bfa"),
        Color(hex: "#fb923c"),
        Color(hex: "#34d399"),
        Color(hex: "#f472b6"),
        Color(hex: "#60a5fa"),
        Color(hex: "#facc15"),
        Color(hex: "#c084fc"),
    ]

    static func setColor(for set: Int) -> Color {
        setColors[abs(set) % setColors.count]
    }
}
