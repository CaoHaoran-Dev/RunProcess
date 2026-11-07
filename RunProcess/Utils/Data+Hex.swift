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
            let next = hexString.index(idx, offsetBy: 2)
            if let b = UInt8(hexString[idx..<next], radix: 16) {
                append(b)
            }
            idx = next
        }
    }
}
