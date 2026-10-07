//
//  AXFailure.swift
//  AppAutomation
//
//  Created by David Sherlock on 2026.
//
//  What an `AXError` means for the caller.
//

import ApplicationServices
import Foundation

/// Accessibility's error codes, as ``AutomationError``.
enum AXFailure {

    /// The error for a failed call.
    ///
    /// - Parameter doing: What was being attempted, in words, for the message.
    static func error(_ status: AXError, doing: String) -> AutomationError {
        switch status {
        case .apiDisabled:
            // What an untrusted process gets for every call — not a fault in
            // the element, so it must not read as one.
            return .notTrusted
        case .cannotComplete:
            return .timedOut(doing)
        case .actionUnsupported:
            return .notPressable(doing, actions: [])
        case .attributeUnsupported, .noValue:
            return .notSettable(doing)
        default:
            return .failed(doing, code: status.rawValue)
        }
    }
}
