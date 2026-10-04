//
//  ANSIParser.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/3.
//

import SwiftUI
internal import AppKit

/// ANSI 解析器
///
/// 支持：
/// - 前景 / 背景色（标准 8 色 + 亮色 + 256 色 + 真彩色）
/// - 粗体、斜体、下划线、反显、暗淡
/// - 各属性的单独重置（SGR 22/23/24/27/39/49）
///
/// 不支持光标移动、清屏、超链接（命令输出里少见）。
enum ANSIParser {

    // MARK: - Public

    /// 把带 ANSI 转义序列的字符串转成 AttributedString
    static func parse(_ input: String) -> AttributedString {
        if !AppSettings.outputColorsEnabled {
            return AttributedString(stripANSI(input))
        }

        var result = AttributedString()
        var state = SGRState()

        var i = input.startIndex
        while i < input.endIndex {
            let ch = input[i]

            if ch == "\u{1B}" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "[" {
                    var j = input.index(after: next)
                    var params = ""
                    var foundTerminator = false
                    while j < input.endIndex {
                        let c = input[j]
                        if c == "m" {
                            foundTerminator = true
                            break
                        }
                        if c.isNumber || c == ";" {
                            params.append(c)
                            j = input.index(after: j)
                        } else {
                            break
                        }
                    }
                    if foundTerminator {
                        applySGR(params, to: &state)
                        i = input.index(after: j)
                        continue
                    }
                }
                i = input.index(after: i)
                continue
            }

            var plain = ""
            while i < input.endIndex, input[i] != "\u{1B}" {
                plain.append(input[i])
                i = input.index(after: i)
            }
            if !plain.isEmpty {
                var piece = AttributedString(plain)
                applyAttributes(state, to: &piece)
                result.append(piece)
            }
        }

        return result
    }

    /// 去掉所有 ANSI 转义序列，返回纯文本
    static func stripANSI(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            if input[i] == "\u{1B}" {
                let next = input.index(after: i)
                if next < input.endIndex, input[next] == "[" {
                    var j = input.index(after: next)
                    var found = false
                    while j < input.endIndex {
                        let c = input[j]
                        if c == "m" {
                            found = true
                            break
                        }
                        if c.isNumber || c == ";" {
                            j = input.index(after: j)
                        } else {
                            break
                        }
                    }
                    if found {
                        i = input.index(after: j)
                        continue
                    }
                }
                i = input.index(after: i)
                continue
            }
            result.append(input[i])
            i = input.index(after: i)
        }
        return result
    }

    // MARK: - 属性状态

    private struct SGRState {
        var foreground: ANSIColor? = nil
        var background: ANSIColor? = nil
        var bold = false
        var dim = false
        var italic = false
        var underline = false
        var reversed = false

        mutating func reset() {
            self = SGRState()
        }
    }

    private enum ANSIColor {
        case standard(Int, bright: Bool)
        case indexed(Int)
        case rgb(Int, Int, Int)
        case defaultForeground
        case defaultBackground

        func color(for scheme: ColorScheme) -> Color {
            switch self {
            case .standard(let n, let bright):
                return Palette.standard(n: n, bright: bright, scheme: scheme)
            case .indexed(let idx):
                return Palette.indexed(idx, scheme: scheme)
            case .rgb(let r, let g, let b):
                return Color(red: Double(r) / 255.0,
                             green: Double(g) / 255.0,
                             blue: Double(b) / 255.0)
            case .defaultForeground:
                return Palette.defaultForeground(for: scheme)
            case .defaultBackground:
                return Palette.defaultBackground(for: scheme)
            }
        }
    }

    // MARK: - SGR 应用

    private static func applySGR(_ params: String, to state: inout SGRState) {
        let codes = params.isEmpty
            ? [0]
            : params.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }

        var i = 0
        while i < codes.count {
            let code = codes[i]
            switch code {
            case 0:
                state.reset()
            case 1:
                state.bold = true
            case 2:
                state.dim = true
            case 3:
                state.italic = true
            case 4:
                state.underline = true
            case 7:
                state.reversed = true
            case 21, 22:
                state.bold = false
                state.dim = false
            case 23:
                state.italic = false
            case 24:
                state.underline = false
            case 27:
                state.reversed = false

            case 30...37:
                state.foreground = .standard(code - 30, bright: false)
            case 39:
                state.foreground = nil
            case 40...47:
                state.background = .standard(code - 40, bright: false)
            case 49:
                state.background = nil
            case 90...97:
                state.foreground = .standard(code - 90, bright: true)
            case 100...107:
                state.background = .standard(code - 100, bright: true)

            case 38, 48:
                if i + 1 < codes.count {
                    let mode = codes[i + 1]
                    if mode == 5, i + 2 < codes.count {
                        let n = codes[i + 2]
                        let color = ANSIColor.indexed(n)
                        if code == 38 { state.foreground = color } else { state.background = color }
                        i += 2
                    } else if mode == 2, i + 4 < codes.count {
                        let r = codes[i + 2]
                        let g = codes[i + 3]
                        let b = codes[i + 4]
                        let color = ANSIColor.rgb(r, g, b)
                        if code == 38 { state.foreground = color } else { state.background = color }
                        i += 4
                    }
                }

            default:
                break
            }
            i += 1
        }
    }

    // MARK: - 应用属性到 AttributedString

    private static func applyAttributes(_ state: SGRState, to piece: inout AttributedString) {
        let scheme = currentColorScheme()

        let effectiveFg: ANSIColor?
        let effectiveBg: ANSIColor?
        if state.reversed {
            effectiveFg = state.background ?? .defaultBackground
            effectiveBg = state.foreground ?? .defaultForeground
        } else {
            effectiveFg = state.foreground
            effectiveBg = state.background
        }

        if let fg = effectiveFg {
            piece.foregroundColor = fg.color(for: scheme)
        }
        if let bg = effectiveBg {
            piece.backgroundColor = bg.color(for: scheme)
        }

        var font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        if state.bold {
            font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        }
        if state.italic {
            let descriptor = font.fontDescriptor.withSymbolicTraits(.italic)
            if let italicFont = NSFont(descriptor: descriptor, size: 13) {
                font = italicFont
            }
        }
        piece.font = Font(font)

        if state.dim {
            let base = piece.foregroundColor ?? Palette.defaultForeground(for: scheme)
            piece.foregroundColor = base.opacity(0.6)
        }

        if state.underline {
            piece.underlineStyle = .single
        }
    }

    // MARK: - ColorScheme 获取

    private static func currentColorScheme() -> ColorScheme {
        switch AppSettings.outputColorScheme {
        case .dark:  return .dark
        case .light: return .light
        case .auto:  break
        }

        if let appearance = NSApp.keyWindow?.effectiveAppearance
            ?? NSApp.mainWindow?.effectiveAppearance {
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? .dark : .light
        }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }

    // MARK: - 色板

    private enum Palette {

        static func standard(n: Int, bright: Bool, scheme: ColorScheme) -> Color {
            let idx = min(max(n, 0), 7)
            if scheme == .dark {
                return bright ? darkBright[idx] : darkNormal[idx]
            } else {
                return bright ? lightBright[idx] : lightNormal[idx]
            }
        }

        static func indexed(_ n: Int, scheme: ColorScheme) -> Color {
            if n < 0 { return .primary }
            if n < 8 { return standard(n: n, bright: false, scheme: scheme) }
            if n < 16 { return standard(n: n - 8, bright: true, scheme: scheme) }
            if n < 232 {
                let i = n - 16
                let r = Double((i / 36) % 6) / 5.0
                let g = Double((i / 6) % 6) / 5.0
                let b = Double(i % 6) / 5.0
                return Color(red: r, green: g, blue: b)
            }
            let v = Double(n - 232) / 23.0
            return Color(red: v, green: v, blue: v)
        }

        static func defaultForeground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.92) : Color(white: 0.12)
        }
        static func defaultBackground(for scheme: ColorScheme) -> Color {
            scheme == .dark ? Color(white: 0.08) : Color(white: 0.98)
        }

        private static let darkNormal: [Color] = [
            Color(red: 0.35, green: 0.35, blue: 0.35),
            Color(red: 0.95, green: 0.35, blue: 0.35),
            Color(red: 0.40, green: 0.85, blue: 0.40),
            Color(red: 0.95, green: 0.80, blue: 0.35),
            Color(red: 0.40, green: 0.65, blue: 0.95),
            Color(red: 0.85, green: 0.50, blue: 0.90),
            Color(red: 0.40, green: 0.85, blue: 0.90),
            Color(red: 0.85, green: 0.85, blue: 0.85),
        ]

        private static let darkBright: [Color] = [
            Color(red: 0.55, green: 0.55, blue: 0.55),
            Color(red: 1.00, green: 0.50, blue: 0.50),
            Color(red: 0.55, green: 1.00, blue: 0.55),
            Color(red: 1.00, green: 0.95, blue: 0.55),
            Color(red: 0.55, green: 0.80, blue: 1.00),
            Color(red: 0.95, green: 0.70, blue: 1.00),
            Color(red: 0.55, green: 1.00, blue: 1.00),
            Color(red: 1.00, green: 1.00, blue: 1.00),
        ]

        private static let lightNormal: [Color] = [
            Color(red: 0.15, green: 0.15, blue: 0.15),
            Color(red: 0.75, green: 0.15, blue: 0.15),
            Color(red: 0.15, green: 0.55, blue: 0.15),
            Color(red: 0.65, green: 0.50, blue: 0.05),
            Color(red: 0.15, green: 0.35, blue: 0.75),
            Color(red: 0.60, green: 0.20, blue: 0.65),
            Color(red: 0.10, green: 0.50, blue: 0.55),
            Color(red: 0.55, green: 0.55, blue: 0.55),
        ]

        private static let lightBright: [Color] = [
            Color(red: 0.40, green: 0.40, blue: 0.40),
            Color(red: 0.90, green: 0.25, blue: 0.25),
            Color(red: 0.20, green: 0.70, blue: 0.20),
            Color(red: 0.80, green: 0.65, blue: 0.10),
            Color(red: 0.25, green: 0.50, blue: 0.90),
            Color(red: 0.75, green: 0.35, blue: 0.80),
            Color(red: 0.15, green: 0.65, blue: 0.70),
            Color(red: 0.10, green: 0.10, blue: 0.10),
        ]
    }
}
