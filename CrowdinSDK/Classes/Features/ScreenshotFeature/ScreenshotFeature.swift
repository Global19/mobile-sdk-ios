//
//  ScreenshotFeature.swift
//  CrowdinSDK
//
//  Created by Serhii Londar on 1/26/19.
//

import UIKit

class ScreenshotFeature {
    static var shared: ScreenshotFeature?
    
    var login: String
    var accountKey: String
    var hash: String
    var credentials: String
    var strings: [String]
    var plurals: [String]
    var sourceLanguage: String
    
    var mappingManager: CrowdinMappingManagerProtocol
    var projectId: Int? = nil
    
    enum Errors: String {
        case storageIdIsMissing = "Storage id is missing."
        case screenshotIdIsMissing = "Screenshot id is missing."
        case unknownError = "Unknown error"
    }
    
    init(login: String, accountKey: String, credentials: String, strings: [String], plurals: [String], hash: String, sourceLanguage: String) {
        self.login = login
        self.accountKey = accountKey
        self.credentials = credentials
        self.strings = strings
        self.plurals = plurals
        self.hash = hash
        self.sourceLanguage = sourceLanguage
        self.mappingManager = CrowdinMappingManager(strings: strings, plurals: plurals, hash: hash, sourceLanguage: sourceLanguage)
        self.loginAndGetProjectId()
    }
    
    func loginAndGetProjectId(success: (() -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        LoginFeature.login(completion: { csrfToken, userAgent, cookies in
            self.getProjectId(csrfToken: csrfToken, userAgent: userAgent, cookies: cookies, success: success, errorHandler: errorHandler)
        }) { (error) in
            errorHandler?(error)
        }
    }
    
    func getProjectId(csrfToken: String, userAgent: String, cookies: [HTTPCookie], success: (() -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        let distrinbutionsAPI = DistributionsAPI(hashString: hash, csrfToken: csrfToken, userAgent: userAgent, cookies: cookies)
        distrinbutionsAPI.getDistribution { (response, error) in
            if let error = error {
                errorHandler?(error)
            } else if let id = response?.data.project.id, let projectId = Int(id) {
                self.projectId = projectId
                success?()
            } else {
                errorHandler?(NSError(domain: Errors.unknownError.rawValue, code: 9999, userInfo: nil))
            }
        }
    }
    
    func captureScreenshot(name: String, success: @escaping (() -> Void), errorHandler: @escaping ((Error?) -> Void)) {
        guard let projectId = self.projectId else {
            self.loginAndGetProjectId(success: {
                DispatchQueue.main.async {
                    self.captureScreenshot(name: name, success: success, errorHandler: errorHandler)
                }
            }, errorHandler: errorHandler)
            return
        }
        guard let screenshot = self.window?.screenshot else { return }
        let values = self.captureValues()
        guard let data = screenshot.pngData() else { return }
        let screenshotsAPI = ScreenshotsAPI(login: login, accountKey: accountKey, credentials: credentials)
        let storageAPI = StorageAPI(login: login, accountKey: accountKey, credentials: credentials)
        storageAPI.uploadNewFile(data: data, completion: { response, error in
            if let error = error {
                errorHandler(error)
                return
            }
            guard let storageId = response?.data.id else {
                errorHandler(NSError(domain: Errors.storageIdIsMissing.rawValue, code: 9999, userInfo: nil))
                return
            }
            screenshotsAPI.createScreenshot(projectId: projectId, storageId: storageId, name: name, completion: { response, error in
                if let error = error {
                    errorHandler(error)
                    return
                }
                guard let screenshotId = response?.data.id else {
                    errorHandler(NSError(domain: Errors.screenshotIdIsMissing.rawValue, code: 9999, userInfo: nil))
                    return
                }
                guard values.count > 0 else { return }
                screenshotsAPI.createScreenshotTags(projectId: projectId, screenshotId: screenshotId, frames: values, completion: { (_, error) in
                    if let error = error {
                        errorHandler(error)
                    } else {
                        success()
                    }
                })
            })
        })
    }
}

extension ScreenshotFeature {
    fileprivate func captureValues() -> [Int: CGRect] {
        guard let window = self.window else { return [Int: CGRect]() }
        let values = self.getValues(from: window)
        let koef = window.screen.scale
        var returnValue = [Int: CGRect]()
        values.forEach { (key: Int, value: CGRect) in
            if window.bounds.contains(value), !value.isValid { // Check wheather control frame is visible on screen.
                returnValue[key] = CGRect(x: value.origin.x * koef, y: value.origin.y * koef, width: value.size.width * koef, height: value.size.height * koef)
            }
        }
        return returnValue
    }
    
    fileprivate func getValues(from view: UIView) -> [Int: CGRect] {
        var description = [Int: CGRect]()
        view.subviews.forEach { (view) in
            if let label = view as? UILabel, let localizationKey = label.localizationKey, let id = mappingManager.id(for: localizationKey) {
                if let frame = label.superview?.convert(label.frame, to: window) {
                    description[id] = frame
                }
            }
            description.merge(with: getValues(from: view))
        }
        return description
    }
}

extension ScreenshotFeature {
    var windows: [UIWindow] { return UIApplication.shared.windows }
    var window: UIWindow? { return UIApplication.shared.keyWindow }
}

extension CGRect {
    var isOriginInfinite: Bool {
        return origin.x == CGFloat.infinity || origin.y == CGFloat.infinity
    }
    
    var validSize: Bool {
        return size.width != 0.0 && size.height != 0
    }
    
    var isValid: Bool {
        return !isInfinite && !isOriginInfinite && validSize
    }
}
