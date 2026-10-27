import SwiftUI

enum Theme {
    static let mint = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.45, green: 0.91, blue: 0.73, alpha: 1) : UIColor(red: 0.06, green: 0.44, blue: 0.32, alpha: 1) })
    static let solar = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 1, green: 0.78, blue: 0.38, alpha: 1) : UIColor(red: 0.65, green: 0.36, blue: 0.02, alpha: 1) })
    static let blue = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.53, green: 0.72, blue: 1, alpha: 1) : UIColor(red: 0.16, green: 0.38, blue: 0.72, alpha: 1) })
    static let violet = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.76, green: 0.65, blue: 1, alpha: 1) : UIColor(red: 0.48, green: 0.29, blue: 0.74, alpha: 1) })
    static let background = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.055, green: 0.075, blue: 0.075, alpha: 1) : UIColor(red: 0.95, green: 0.965, blue: 0.955, alpha: 1) })
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.095, green: 0.12, blue: 0.12, alpha: 1) : UIColor.white })
    static let inset = Color.primary.opacity(0.035)
}

struct EnergyCard<Content: View>: View {
    var title: String?
    var eyebrow: String?
    @ViewBuilder var content: Content
    init(_ title: String? = nil, eyebrow: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.eyebrow = eyebrow
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let eyebrow { Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).tracking(1.8).foregroundStyle(.secondary) }
            if let title { Text(title).font(.title3.weight(.semibold)) }
            content
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.045), lineWidth: 1) }
    }
}

struct StatusPill: View {
    var title: String
    var color: Color = Theme.mint
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(color.opacity(0.10), in: Capsule())
        .foregroundStyle(color)
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var subtitle: String
    var symbol: String
    var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
            Text(value).font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SectionIntro: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.mint)
            Text(title).font(.system(.largeTitle, design: .rounded, weight: .semibold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
}

struct InfoRow: View {
    var title: String
    var value: String
    var color: Color = .primary
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).foregroundStyle(color).multilineTextAlignment(.trailing).monospacedDigit()
        }.font(.subheadline)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .foregroundStyle(Theme.background)
            .background(Theme.mint.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PageLayout<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) { content }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .frame(maxWidth: 1220).frame(maxWidth: .infinity)
        }
        .background(Theme.background)
    }
}
