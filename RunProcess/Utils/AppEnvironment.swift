//
//  AppEnvironment.swift
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import Foundation

enum AppEnvironment {

    /// 是否为测试构建（由 test target 的 Other Swift Flags 注入 -D RUNPROCESS_TEST）
    static var isTest: Bool {
        #if RUNPROCESS_TEST
        return true
        #else
        return false
        #endif
    }

    /// 是否为 Preview / Beta 构建（-D BETA）
    static var isBeta: Bool {
        #if BETA
        return true
        #else
        return false
        #endif
    }

    /// 用户数据目录名。
    /// - 正式版：RunProcess
    /// - Preview / Beta：RunProcess-Beta-Test
    /// - 测试构建（RUNPROCESS_TEST）：RunProcess-Beta-Test
    static var appSupportFolderName: String {
        if isTest || isBeta {
            return "RunProcess-Beta-Test"
        }
        return "RunProcess"
    }
}
