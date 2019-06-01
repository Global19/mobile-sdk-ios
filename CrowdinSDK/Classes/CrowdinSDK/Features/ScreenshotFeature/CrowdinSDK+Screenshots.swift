//
//  CrowdinSDK+ScreenshotFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 6/1/19.
//

import Foundation

extension CrowdinSDK {
    @objc class func initializeScreenshotFeature() {
        guard let config = CrowdinSDK.config else { return }
        let crowdinProviderConfig = config.crowdinProviderConfig ?? CrowdinProviderConfig()
        if let crowdinScreenshotsConfig = config.crowdinScreenshotsConfig {
            ScreenshotFeature.shared = ScreenshotFeature(login: crowdinScreenshotsConfig.login, accountKey: crowdinScreenshotsConfig.accountKey, credentials: crowdinScreenshotsConfig.credentials, strings: crowdinProviderConfig.stringsFileNames, plurals: crowdinProviderConfig.pluralsFileNames, hash: crowdinProviderConfig.hashString, sourceLanguage: crowdinProviderConfig.sourceLanguage)
        }
    }
}
