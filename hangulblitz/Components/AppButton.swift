//
//  AppButton.swift
//  hangulblitz
//

import SwiftUI

enum AppButtonVariant: CaseIterable {
    case filled
    case outlined
    case muted
}

enum AppButtonSize: CaseIterable {
    case large
    case medium
    case small

    fileprivate var font: Font {
        switch self {
        case .large, .medium:
            .headline
        case .small:
            .footnote
        }
    }

    fileprivate var minimumHeight: CGFloat? {
        switch self {
        case .large:
            56
        case .medium:
            48
        case .small:
            nil
        }
    }

    fileprivate var horizontalPadding: CGFloat {
        switch self {
        case .large, .medium:
            32
        case .small:
            16
        }
    }
}

enum AppButtonWidth {
    case hug
    case fixed(CGFloat)
    case fill

    fileprivate var minimumWidth: CGFloat? {
        guard case let .fixed(value) = self else { return nil }
        return value
    }

    fileprivate var maximumWidth: CGFloat? {
        switch self {
        case .hug:
            nil
        case let .fixed(value):
            value
        case .fill:
            .infinity
        }
    }
}

struct AppButton<Label: View>: View {
    let style: AppButtonVariant
    let size: AppButtonSize
    let width: AppButtonWidth
    let action: () -> Void

    private let label: Label

    init(
        style: AppButtonVariant = .filled,
        size: AppButtonSize = .medium,
        width: AppButtonWidth = .hug,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.style = style
        self.size = size
        self.width = width
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .font(size.font)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, 8)
                .frame(
                    minWidth: width.minimumWidth,
                    maxWidth: width.maximumWidth,
                    minHeight: size.minimumHeight
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(AppButtonAppearance(style: style))
    }
}

/// A filled app button with a purely visual remaining-time layer. The practice
/// session owns the clock and timeout decision; this component only renders the
/// supplied fraction so animation frame rate can never change a score.
struct TimedAppButton<Label: View>: View {
    let remainingFraction: Double
    let size: AppButtonSize
    let width: AppButtonWidth
    let action: () -> Void

    private let label: Label

    init(
        remainingFraction: Double,
        size: AppButtonSize = .large,
        width: AppButtonWidth = .fill,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.remainingFraction = remainingFraction
        self.size = size
        self.width = width
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Color.black.opacity(0.1)
                            .frame(
                                width: geometry.size.width
                                    * min(max(remainingFraction, 0), 1)
                            )

                        Spacer(minLength: 0)
                    }
                }

                label
                    .font(size.font)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, size.horizontalPadding)
                    .padding(.vertical, 8)
            }
            .frame(
                minWidth: width.minimumWidth,
                maxWidth: width.maximumWidth,
                minHeight: size.minimumHeight
            )
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(.capsule)
        }
        .buttonStyle(AppButtonAppearance(style: .filled))
        .accessibilityValue(
            Text(
                verbatim: min(max(remainingFraction, 0), 1)
                    .formatted(.percent.precision(.fractionLength(0)))
            )
        )
    }
}

private struct AppButtonAppearance: ButtonStyle {
    let style: AppButtonVariant

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(style.foregroundColor)
            .background {
                Capsule()
                    .fill(style.backgroundColor)
            }
            .overlay {
                Capsule()
                    .strokeBorder(style.borderColor, lineWidth: style == .outlined ? 1 : 0)
            }
            .contentShape(.capsule)
            .opacity(opacity(isPressed: configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func opacity(isPressed: Bool) -> Double {
        guard isEnabled else { return 0.45 }
        return isPressed ? 0.72 : 1
    }
}

private extension AppButtonVariant {
    var foregroundColor: Color {
        switch self {
        case .filled:
            .onAccent
        case .outlined, .muted:
            .accentColor
        }
    }

    var backgroundColor: Color {
        switch self {
        case .filled:
            .accentColor
        case .outlined:
            .clear
        case .muted:
            Color("Muted")
        }
    }

    var borderColor: Color {
        self == .outlined ? .accentColor : .clear
    }
}

#Preview("App button styles and sizes") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(AppButtonSize.allCases, id: \.self) { size in
                ForEach(AppButtonVariant.allCases, id: \.self) { style in
                    AppButton(style: style, size: size, action: {}) {
                        Text(verbatim: "Label")
                    }
                }
            }

            AppButton(style: .filled, size: .medium, action: {}) {
                Text(verbatim: "Disabled")
            }
            .disabled(true)

            AppButton(style: .outlined, size: .medium, action: {}) {
                Text(verbatim: "A longer localised button label")
            }
            .frame(maxWidth: 280)

            TimedAppButton(remainingFraction: 0.72, action: {}) {
                Text(verbatim: "Check Answer")
            }
        }
        .padding(24)
    }
    //.background(Color(.systemGroupedBackground))
}
