//
//  ANSIParser.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/3.
//

import SwiftUI
internal import AppKit

/// 轻量 ANSI 解析器：支持前景色 / 背景色 / 粗体 / 下划线 / 斜体
/// 不支持：光标移动、清屏、超链接（这些在命令输出里少见）
enum ANSIParser {

    /// 把带 ANSI 转义序列的字符串转成 AttributedString
    static func parse(_ input: String) -> AttributedString {
        var result = AttributedString()
        var current = Attributes()

        var i = input.startIndex
        while i < input.endIndex {
            let ch = input[i]

            if ch == "\u{1B}", input.index(after: i) < input.endIndex,
               input[input.index(after: i)] == "[" {
                // ESC [ ... m
                var j = input.index(i, offsetBy: 2)
                var params = ""
                while j < input.endIndex, input[j] != "m" {
                    params.append(input[j])
                    j = input.index(after: j)
                }
                if j < input.endIndex {
                    applySGR(params, to: &current)
                    i = input.index(after: j)
                    continue
                }
            }

            var piece = AttributedString(String(ch))
            piece.foregroundColor = current.foreground
            piece.backgroundColor = current.background
            if current.bold { piece.font = .system(size: 13, weight: .bold, design: .monospaced) }
            else if current.italic { piece.font = .system(size: 13, design: .monospaced).italic() }
            else { piece.font = .system(size: 13, design: .monospaced) }
            if current.underline { piece.underlineStyle = .single }

            result.append(piece)
            i = input.index(after: i)
        }
        return result
    }

    // MARK: - Attributes

    private struct Attributes {
        var foreground: Color?
        var background: Color?
        var bold = false
        var italic = false
        var underline = false
    }

    // MARK: - SGR

    private static func applySGR(_ params: String, to attrs: inout Attributes) {
        let codes = params.split(separator: ";").map { Int($0) ?? 0 }
        let list = codes.isEmpty ? [0] : codes
        var idx = 0

        while idx < list.count {
            let code = list[idx]
            switch code {
            case 0:
                attrs = Attributes()
            case 1: attrs.bold = true
            case 3: attrs.italic = true
            case 4: attrs.underline = true
            case 22: attrs.bold = false
            case 23: attrs.italic = false
            case 24: attrs.underline = false
            case 30...37:
                attrs.foreground = standardColor(code - 30, bright: false)
            case 39:
                attrs.foreground = nil
            case 40...47:
                attrs.background = standardColor(code - 40, bright: false)
            case 49:
                attrs.background = nil
            case 90...97:
                attrs.foreground = standardColor(code - 90, bright: true)
            case 100...107:
                attrs.background = standardColor(code - 100, bright: true)
            case 38, 48:
                // 38;5;N 或 38;2;R;G;B
                if idx + 1 < list.count {
                    let mode = list[idx + 1]
                    if mode == 5, idx + 2 < list.count {
                        let n = list[idx + 2]
                        let color = xterm256(n)
                        if code == 38 { attrs.foreground = color } else { attrs.background = color }
                        idx += 2
                    } else if mode == 2, idx + 4 < list.count {
                        let r = Double(list[idx + 2]) / 255
                        let g = Double(list[idx + 3]) / 255
                        let b = Double(list[idx + 4]) / 255
                        let color = Color(red: r, green: g, blue: b)
                        if code == 38 { attrs.foreground = color } else { attrs.background = color }
                        idx += 4
                    }
                }
            default:
                break
            }
            idx += 1
        }
    }

    private static func standardColor(_ n: Int, bright: Bool) -> Color {
        // 近似 ANSI 标准色，用 macOS 系统色板
        let base: [Color] = [
            Color(red: 0.12, green: 0.12, blue: 0.12), // black
            Color(red: 0.78, green: 0.22, blue: 0.20), // red
            Color(red: 0.20, green: 0.65, blue: 0.25), // green
            Color(red: 0.80, green: 0.65, blue: 0.10), // yellow
            Color(red: 0.18, green: 0.40, blue: 0.78), // blue
            Color(red: 0.65, green: 0.25, blue: 0.70), // magenta
            Color(red: 0.20, green: 0.65, blue: 0.70), // cyan
            Color(red: 0.85, green: 0.85, blue: 0.85), // white
        ]
        let brightOffset: [Color] = [
            Color(red: 0.45, green: 0.45, blue: 0.45),
            Color(red: 0.95, green: 0.40, blue: 0.38),
            Color(red: 0.40, green: 0.85, blue: 0.45),
            Color(red: 0.95, green: 0.85, blue: 0.30),
            Color(red: 0.40, green: 0.65, blue: 0.95),
            Color(red: 0.85, green: 0.50, blue: 0.90),
            Color(red: 0.40, green: 0.85, blue: 0.90),
            Color(red: 1.00, green: 1.00, blue: 1.00),
        ]
        let i = min(max(n, 0), 7)
        return bright ? brightOffset[i] : base[i]
    }

    private static func xterm256(_ n: Int) -> Color {
        if n < 16 { return standardColor(n % 8, bright: n >= 8) }
        if n < 232 {
            let i = n - 16
            let r = Double((i / 36) % 6) / 5
            let g = Double((i / 6) % 6) / 5
            let b = Double(i % 6) / 5
            return Color(red: r, green: g, blue: b)
        }
        let v = Double(n - 232) / 23
        return Color(red: v, green: v, blue: v)
    }
}
