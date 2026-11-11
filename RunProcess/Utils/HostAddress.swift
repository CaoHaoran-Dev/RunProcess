//
//  HostAddress.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/11.
//

import Foundation

nonisolated enum HostAddress {

    /// 去掉用户可能误输入的 `:port`，返回纯 host 部分。
    /// - `192.168.1.10:52731` → `192.168.1.10`
    /// - `[fe80::1]:52731` → `fe80::1`
    /// - `fe80::1` → `fe80::1`（裸 IPv6 不剥）
    static func stripPort(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        // [IPv6]:port
        if trimmed.hasPrefix("["),
           let close = trimmed.firstIndex(of: "]") {
            return String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
        }

        // 单个冒号且右侧是数字：IPv4:port / hostname:port
        let colons = trimmed.filter { $0 == ":" }.count
        if colons == 1,
           let idx = trimmed.lastIndex(of: ":") {
            let portPart = String(trimmed[trimmed.index(after: idx)...])
            if Int(portPart) != nil {
                return String(trimmed[..<idx])
            }
        }

        // 多个冒号视为裸 IPv6，原样返回
        return trimmed
    }

    /// 是否为合法的 IPv4 点分十进制。
    static func isIPv4(_ host: String) -> Bool {
        var addr = in_addr()
        return inet_pton(AF_INET, host, &addr) == 1
    }

    /// 是否为合法的 IPv6 字面量（不含方括号）。
    static func isIPv6(_ host: String) -> Bool {
        var addr = in6_addr()
        return inet_pton(AF_INET6, host, &addr) == 1
    }

    /// 是否为合法主机名（含 .local、域名）。
    static func isHostname(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            let allowed = label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
            if !allowed { return false }
            if label.hasPrefix("-") || label.hasSuffix("-") { return false }
        }
        return true
    }

    /// host 是否可接受（IPv4 / IPv6 / 主机名）。
    static func isValid(_ host: String) -> Bool {
        isIPv4(host) || isIPv6(host) || isHostname(host)
    }

    /// 给 URL 拼接用：IPv6 字面量加方括号，其他原样。
    static func formattedForURL(_ host: String) -> String {
        let stripped = stripPort(host)
        if isIPv6(stripped) {
            return "[\(stripped)]"
        }
        return stripped
    }

    /// 给 NWEndpoint.Host 用：去掉方括号，裸串。
    static func bareHost(_ host: String) -> String {
        stripPort(host)
    }
}
