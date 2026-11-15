//
//  Data+Hex.swift
//  RunProcess
//
//  Created by Haoran on 2026/11/7.
//

import Foundation

extension Data {
    nonisolated init(hexString: String) {
        self.init()
        var idx = hexString.startIndex
        while idx < hexString.endIndex {
            // 防越界：确保后面至少还有 1 个字符
            guard let next = hexString.index(idx, offsetBy: 2, limitedBy: hexString.endIndex) else { break }
            if let b = UInt8(hexString[idx..<next], radix: 16) {
                append(b)
            }
            idx = next
        }
    }
}
