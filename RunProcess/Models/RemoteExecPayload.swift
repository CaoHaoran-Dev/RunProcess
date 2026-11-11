//
//  RemoteExecPayload.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/11.
//

#if BETA

import Foundation

/// 通过 `ClientMessage.custom(type: "exec-v2")` 传递的扩展执行请求。
/// 不改 RemoteProcessProtocol 的前提下，给 exec 增加 kind。
nonisolated struct RemoteExecPayload: Codable {
    let id: String
    let cmd: String
    let kind: String
    let timeout: TimeInterval

    enum Kind: String, Codable {
        case command
        case sudo
        case workflow
        case alias
        case history
        case file
    }

    var execKind: Kind {
        Kind(rawValue: kind) ?? .command
    }
}

#endif
