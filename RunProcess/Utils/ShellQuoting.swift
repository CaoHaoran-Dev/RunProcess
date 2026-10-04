//
//  ShellQuoting.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/4.
//

import Foundation

/// shell 路径转义工具
///
/// 用双引号包裹含特殊字符的路径，转义内部的 `"` 和 `\`。
/// 不需要引号时（只有字母数字和 `_-./~@+`）原样返回。
enum ShellQuoting {

    /// 用双引号包裹路径，转义内部的 " 和 \
    static func quote(_ path: String) -> String {
        let needsQuote = path.contains { ch in
            !ch.isLetter && !ch.isNumber
                && !"_-./~@+".contains(ch)
        }
        guard needsQuote else { return path }

        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// 批量处理，空格分隔
    static func quoteAll(_ paths: [String]) -> String {
        paths.map { quote($0) }.joined(separator: " ")
    }
}
