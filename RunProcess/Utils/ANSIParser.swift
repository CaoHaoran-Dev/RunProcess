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
/// - 前景 / 背景色（标准 8 色 + 亮色 + 256 色 + 24-bit 真彩色）
/// - 粗体、斜体、下划线、反显、暗淡
/// - 各属性的单独重置（SGR 22/23/24/27/39/49）
enum ANSIParser {

    // MARK: - Public

    static func parse(_ input: String) -> NSAttributedString {
        if !AppSettings.outputColorsEnabled {
            return plain(stripANSI(input))
        }

        let result = NSMutableAttributedString()
        var state = SGRState()

        // 把同状态的连续字符攒起来，减少 NSTextStorage 的属性片段数量
        var buffer = ""
        var bufferState = state

        func flush() {
            guard !buffer.isEmpty else { return }
            result.append(styledPiece(buffer, state: bufferState))
            buffer = ""
        }

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
                        flush()
                        applySGR(params, to: &state)
                        bufferState = state
                        i = input.index(after: j)
                        continue
                    }
                }
                i = input.index(after: i)
                continue
            }

            if buffer.isEmpty {
                bufferState = state
            }
            buffer.append(ch)
            i = input.index(after: i)
        }
        flush()

        return result
    }

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

    // MARK: - 纯文本

    private static func plain(_ text: String) -> NSAttributedString {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: OutputFont.regular,
            .foregroundColor: NSColor.labelColor
        ]
        return NSAttributedString(string: text, attributes: attrs)
    }

    // MARK: - 单段属性

    private static func styledPiece(_ text: String, state: SGRState) -> NSAttributedString {
        let scheme: ColorScheme = currentColorScheme()

        let effectiveFg: ANSIColor?
        let effectiveBg: ANSIColor?
        if state.reversed {
            effectiveFg = state.background ?? .defaultBackground
            effectiveBg = state.foreground ?? .defaultForeground
        } else {
            effectiveFg = state.foreground
            effectiveBg = state.background
        }

        var attrs: [NSAttributedString.Key: Any] = [:]

        // 字体
        var font: NSFont = OutputFont.regular
        if state.bold { font = OutputFont.bold }
        if state.italic { font = OutputFont.italic }
        attrs[.font] = font

        // 前景色
        if let fg = effectiveFg {
            var color: NSColor = fg.nsColor(for: scheme)
            if state.dim {
                color = color.withAlphaComponent(0.6)
            }
            attrs[.foregroundColor] = color
        } else {
            var color: NSColor = Palette.defaultForeground(for: scheme)
            if state.dim {
                color = color.withAlphaComponent(0.6)
            }
            attrs[.foregroundColor] = color
        }

        // 背景色
        if let bg = effectiveBg {
            attrs[.backgroundColor] = bg.nsColor(for: scheme)
        }

        // 下划线
        if state.underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return NSAttributedString(string: text, attributes: attrs)
    }

    // MARK: - 状态

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

        func nsColor(for scheme: ColorScheme) -> NSColor {
            switch self {
            case .standard(let n, let bright):
                return Palette.standard(n: n, bright: bright, scheme: scheme)
            case .indexed(let idx):
                return Palette.indexed(idx, scheme: scheme)
            case .rgb(let r, let g, let b):
                return NSColor(red: CGFloat(r) / 255.0,
                               green: CGFloat(g) / 255.0,
                               blue: CGFloat(b) / 255.0,
                               alpha: 1.0)
            case .defaultForeground:
                return Palette.defaultForeground(for: scheme)
            case .defaultBackground:
                return Palette.defaultBackground(for: scheme)
            }
        }
    }

    // MARK: - SGR 应用

    private static func applySGR(_ params: String, to state: inout SGRState) {
        let codes: [Int] = params.isEmpty
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
                    } else if i + 3 < codes.count {
                        // 简写 38;R;G;B
                        let r = codes[i + 1]
                        let g = codes[i + 2]
                        let b = codes[i + 3]
                        let color = ANSIColor.rgb(r, g, b)
                        if code == 38 { state.foreground = color } else { state.background = color }
                        i += 3
                    }
                }

            default:
                break
            }
            i += 1
        }
    }

    // MARK: - ColorScheme

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

        static func standard(n: Int, bright: Bool, scheme: ColorScheme) -> NSColor {
            let idx = min(max(n, 0), 7)
            if scheme == .dark {
                return bright ? darkBright[idx] : darkNormal[idx]
            } else {
                return bright ? lightBright[idx] : lightNormal[idx]
            }
        }

        static func indexed(_ n: Int, scheme: ColorScheme) -> NSColor {
            if n < 0 { return .labelColor }
            if n < 8 { return standard(n: n, bright: false, scheme: scheme) }
            if n < 16 { return standard(n: n - 8, bright: true, scheme: scheme) }
            if n < 232 {
                let i = n - 16
                let r = CGFloat((i / 36) % 6) / 5.0
                let g = CGFloat((i / 6) % 6) / 5.0
                let b = CGFloat(i % 6) / 5.0
                return NSColor(red: r, green: g, blue: b, alpha: 1.0)
            }
            let v = CGFloat(n - 232) / 23.0
            return NSColor(white: v, alpha: 1.0)
        }

        static func defaultForeground(for scheme: ColorScheme) -> NSColor {
            scheme == .dark
                ? NSColor(white: 0.92 as CGFloat, alpha: 1)
                : NSColor(white: 0.12 as CGFloat, alpha: 1)
        }

        static func defaultBackground(for scheme: ColorScheme) -> NSColor {
            scheme == .dark
                ? NSColor(white: 0.08 as CGFloat, alpha: 1)
                : NSColor(white: 0.98 as CGFloat, alpha: 1)
        }

        private static let darkNormal: [NSColor] = [
            NSColor(red: 0.35 as CGFloat, green: 0.35 as CGFloat, blue: 0.35 as CGFloat, alpha: 1),
            NSColor(red: 0.95 as CGFloat, green: 0.35 as CGFloat, blue: 0.35 as CGFloat, alpha: 1),
            NSColor(red: 0.40 as CGFloat, green: 0.85 as CGFloat, blue: 0.40 as CGFloat, alpha: 1),
            NSColor(red: 0.95 as CGFloat, green: 0.80 as CGFloat, blue: 0.35 as CGFloat, alpha: 1),
            NSColor(red: 0.40 as CGFloat, green: 0.65 as CGFloat, blue: 0.95 as CGFloat, alpha: 1),
            NSColor(red: 0.85 as CGFloat, green: 0.50 as CGFloat, blue: 0.90 as CGFloat, alpha: 1),
            NSColor(red: 0.40 as CGFloat, green: 0.85 as CGFloat, blue: 0.90 as CGFloat, alpha: 1),
            NSColor(red: 0.85 as CGFloat, green: 0.85 as CGFloat, blue: 0.85 as CGFloat, alpha: 1),
        ]

        private static let darkBright: [NSColor] = [
            NSColor(red: 0.55 as CGFloat, green: 0.55 as CGFloat, blue: 0.55 as CGFloat, alpha: 1),
            NSColor(red: 1.00 as CGFloat, green: 0.50 as CGFloat, blue: 0.50 as CGFloat, alpha: 1),
            NSColor(red: 0.55 as CGFloat, green: 1.00 as CGFloat, blue: 0.55 as CGFloat, alpha: 1),
            NSColor(red: 1.00 as CGFloat, green: 0.95 as CGFloat, blue: 0.55 as CGFloat, alpha: 1),
            NSColor(red: 0.55 as CGFloat, green: 0.80 as CGFloat, blue: 1.00 as CGFloat, alpha: 1),
            NSColor(red: 0.95 as CGFloat, green: 0.70 as CGFloat, blue: 1.00 as CGFloat, alpha: 1),
            NSColor(red: 0.55 as CGFloat, green: 1.00 as CGFloat, blue: 1.00 as CGFloat, alpha: 1),
            NSColor(red: 1.00 as CGFloat, green: 1.00 as CGFloat, blue: 1.00 as CGFloat, alpha: 1),
        ]

        private static let lightNormal: [NSColor] = [
            NSColor(red: 0.15 as CGFloat, green: 0.15 as CGFloat, blue: 0.15 as CGFloat, alpha: 1),
            NSColor(red: 0.75 as CGFloat, green: 0.15 as CGFloat, blue: 0.15 as CGFloat, alpha: 1),
            NSColor(red: 0.15 as CGFloat, green: 0.55 as CGFloat, blue: 0.15 as CGFloat, alpha: 1),
            NSColor(red: 0.65 as CGFloat, green: 0.50 as CGFloat, blue: 0.05 as CGFloat, alpha: 1),
            NSColor(red: 0.15 as CGFloat, green: 0.35 as CGFloat, blue: 0.75 as CGFloat, alpha: 1),
            NSColor(red: 0.60 as CGFloat, green: 0.20 as CGFloat, blue: 0.65 as CGFloat, alpha: 1),
            NSColor(red: 0.10 as CGFloat, green: 0.50 as CGFloat, blue: 0.55 as CGFloat, alpha: 1),
            NSColor(red: 0.55 as CGFloat, green: 0.55 as CGFloat, blue: 0.55 as CGFloat, alpha: 1),
        ]

        private static let lightBright: [NSColor] = [
            NSColor(red: 0.40 as CGFloat, green: 0.40 as CGFloat, blue: 0.40 as CGFloat, alpha: 1),
            NSColor(red: 0.90 as CGFloat, green: 0.25 as CGFloat, blue: 0.25 as CGFloat, alpha: 1),
            NSColor(red: 0.20 as CGFloat, green: 0.70 as CGFloat, blue: 0.20 as CGFloat, alpha: 1),
            NSColor(red: 0.80 as CGFloat, green: 0.65 as CGFloat, blue: 0.10 as CGFloat, alpha: 1),
            NSColor(red: 0.25 as CGFloat, green: 0.50 as CGFloat, blue: 0.90 as CGFloat, alpha: 1),
            NSColor(red: 0.75 as CGFloat, green: 0.35 as CGFloat, blue: 0.80 as CGFloat, alpha: 1),
            NSColor(red: 0.15 as CGFloat, green: 0.65 as CGFloat, blue: 0.70 as CGFloat, alpha: 1),
            NSColor(red: 0.10 as CGFloat, green: 0.10 as CGFloat, blue: 0.10 as CGFloat, alpha: 1),
        ]
    }
}
