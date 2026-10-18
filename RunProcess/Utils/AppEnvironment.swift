//
//  AppEnvironment.swif
//  RunProcess
//
//  Created by Haoran on 2026/10/18.
//

import Foundation

enum AppEnvironment {
    #if BETA
    static let isBeta = true
    static let appSupportFolderName = "RunProcess-Beta"
    #else
    static let isBeta = false
    static let appSupportFolderName = "RunProcess"
    #endif
}
