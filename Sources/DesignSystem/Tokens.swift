import SwiftUI

// MARK: - Design tokens

enum DS {
    // Surfaces
    static let bg         = Color(hex: 0x0B0C0E)
    static let bg1        = Color(hex: 0x121317)
    static let bg2        = Color(hex: 0x181A1F)
    static let bg3        = Color(hex: 0x20232A)
    static let line       = Color.white.opacity(0.06)
    static let lineStrong = Color.white.opacity(0.12)

    // Foreground
    static let fg  = Color(hex: 0xF2F3F5)
    static let fg2 = Color(hex: 0xB8BCC4)
    static let fg3 = Color(hex: 0x6E7480)
    static let fg4 = Color(hex: 0x4A4F58)

    // Accent — lime
    static let accent    = Color(hex: 0xC8FF4A)
    static let accentDim = Color(hex: 0x8EBC1F)
    static let accentInk = Color(hex: 0x0B0C0E)

    // Glucose semantic
    static let hi = Color(hex: 0xFF6B5B)   // hyper / high
    static let lo = Color(hex: 0xFFB347)   // hypo  / low

    // Radii
    static let r:   CGFloat = 14
    static let rSm: CGFloat = 8
    static let rXs: CGFloat = 6

    // Density
    enum Density: String, CaseIterable { case compact, comfortable, spacious }

    static func pad(_ d: Density) -> CGFloat {
        switch d { case .compact: 12; case .comfortable: 16; case .spacious: 22 }
    }
    static func gap(_ d: Density) -> CGFloat {
        switch d { case .compact: 8; case .comfortable: 12; case .spacious: 18 }
    }
    static func rowH(_ d: Density) -> CGFloat {
        switch d { case .compact: 40; case .comfortable: 48; case .spacious: 56 }
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Monospaced font scale

extension Font {
    static let dsMonoXl = Font.system(size: 64, weight: .medium,  design: .monospaced)
    static let dsMonoLg = Font.system(size: 32, weight: .medium,  design: .monospaced)
    static let dsMono   = Font.system(size: 18, weight: .regular, design: .monospaced)
    static let dsMonoSm = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let dsMonoXs = Font.system(size: 10, weight: .regular, design: .monospaced)
}

// MARK: - Density environment key

private struct DensityKey: EnvironmentKey {
    static let defaultValue: DS.Density = .compact
}

extension EnvironmentValues {
    var dsDensity: DS.Density {
        get { self[DensityKey.self] }
        set { self[DensityKey.self] = newValue }
    }
}

// MARK: - Shared primitives

/// Card container matching `bg1` fill + `line` border + `DS.r` corner.
struct DSCard<Content: View>: View {
    @Environment(\.dsDensity) private var density
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(DS.pad(density))
            .background(DS.bg1, in: RoundedRectangle(cornerRadius: DS.r))
            .overlay(RoundedRectangle(cornerRadius: DS.r).stroke(DS.line, lineWidth: 1))
    }
}

/// Section label — mono 10pt uppercase, tracked, `fg3`.
struct DSSectionHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.dsMonoXs)
            .tracking(1.4)
            .foregroundStyle(DS.fg3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// App-bar: mono title + right slot.
struct DSAppBar: View {
    let title: String
    var status: DSStatusPill.Status = .live
    var right: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.dsMonoXs)
                .tracking(1.4)
                .foregroundStyle(DS.fg3)
            Spacer()
            if let r = right { r }
            DSStatusPill(status: status)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(DS.bg)
        .overlay(alignment: .bottom) {
            DS.line.frame(height: 1)
        }
    }
}

struct DSStatusPill: View {
    enum Status { case live, synced, stale, off }
    let status: Status

    private var dotColor: Color {
        switch status {
        case .live, .synced: return DS.accent
        case .stale:         return DS.hi
        case .off:           return DS.fg4
        }
    }
    private var label: String {
        switch status {
        case .live:   return "LIVE"
        case .synced: return "SYNCED"
        case .stale:  return "STALE"
        case .off:    return "OFF"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: dotColor, radius: 4)
            Text(label)
                .font(.dsMonoXs)
                .tracking(0.8)
                .foregroundStyle(DS.fg2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DS.bg3, in: Capsule())
        .overlay(Capsule().stroke(DS.lineStrong, lineWidth: 1))
    }
}

/// Inline badge (e.g. "SYNCED 2m", "STREAK 12d").
struct DSBadge: View {
    let text: String
    var accent: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(.dsMonoXs)
            .tracking(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(accent ? DS.accent : DS.bg3,
                        in: RoundedRectangle(cornerRadius: DS.rXs))
            .foregroundStyle(accent ? DS.accentInk : DS.fg2)
    }
}

/// 3-column stat grid row.
struct DSStatStrip: View {
    struct Cell {
        let label: String
        let value: String
        var delta: String? = nil
        var deltaUp: Bool? = nil   // nil = neutral, true = up (lime), false = down (red)
        var valueColor: Color = DS.fg
    }

    let cells: [Cell]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, cell in
                if i > 0 {
                    DS.line.frame(width: 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(cell.label.uppercased())
                        .font(.dsMonoXs)
                        .tracking(1.2)
                        .foregroundStyle(DS.fg3)
                    Text(cell.value)
                        .font(.dsMono)
                        .foregroundStyle(cell.valueColor)
                        .monospacedDigit()
                    if let d = cell.delta {
                        Text(d)
                            .font(.dsMonoXs)
                            .foregroundStyle(
                                cell.deltaUp == true  ? DS.accent :
                                cell.deltaUp == false ? DS.hi     : DS.fg3
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DS.bg1)
            }
        }
        .background(DS.line) // hairline between cells
        .clipShape(RoundedRectangle(cornerRadius: DS.rSm))
        .overlay(RoundedRectangle(cornerRadius: DS.rSm).stroke(DS.line, lineWidth: 1))
    }
}

/// Toggle row (label + sub + system toggle).
struct DSToggleRow: View {
    let label: String
    var sub: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.fg)
                if let s = sub {
                    Text(s)
                        .font(.dsMonoXs)
                        .foregroundStyle(DS.fg3)
                }
            }
        }
        .tint(DS.accent)
        .padding(.vertical, 2)
    }
}

/// Key-value row (label left, mono value right).
struct DSKVRow: View {
    let key: String
    let value: String
    var valueColor: Color = DS.fg2
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(key)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.fg)
                Spacer()
                Text(value)
                    .font(.dsMonoSm)
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
            }
            .padding(.vertical, 12)
            if showDivider {
                DS.line.frame(height: 1)
            }
        }
    }
}
