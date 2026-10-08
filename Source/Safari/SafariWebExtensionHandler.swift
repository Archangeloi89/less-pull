//
//  SafariWebExtensionHandler.swift
//  Less Pull for Safari Extension
//
//  Forwards the extension's messages to the Less Pull app over its Mach message
//  port (the sandbox allows that one name), with the same JSON requests and
//  replies the Chromium and Firefox host uses over the local socket. Safari identifies the
//  extension itself (the app extension is the trust boundary), so no origin
//  argument is checked here. Nothing leaves the Mac.
//
//  © 2026 Jiri Arion Rose. See LICENSE-APP.txt and LICENSE-SOURCE.txt.
//

import SafariServices
import Foundation

class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    /// One session per extension process, so the app can expire this browser's
    /// context when the process goes away (the heartbeat keeps it fresh).
    static let session = UUID().uuidString

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        var message = (request?.userInfo?[SFExtensionMessageKey] as? [String: Any]) ?? [:]
        message["session"] = Self.session
        message["browser"] = "com.apple.Safari"
        var reply = Self.send(message)
        if let id = message["id"] { reply["id"] = id }
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: reply]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }

    /// The app's message port; the sandbox allows exactly this name (see the entitlements).
    static let portName = "com.jiriarion.lesspull.bridge" as CFString

    static func send(_ message: [String: Any]) -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(message), let data = try? JSONSerialization.data(withJSONObject: message) else {
            return ["ok": false, "error": "Invalid message"]
        }
        guard let port = CFMessagePortCreateRemote(nil, portName) else {
            return ["ok": false, "error": "Open Less Pull on this Mac, then try again."]
        }
        var reply: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(port, 1, data as CFData, 4, 4, CFRunLoopMode.defaultMode.rawValue, &reply)
        CFMessagePortInvalidate(port)
        guard status == kCFMessagePortSuccess, let replyData = reply?.takeRetainedValue() as Data?,
              let parsed = try? JSONSerialization.jsonObject(with: replyData) as? [String: Any] else {
            return ["ok": false, "error": "Less Pull did not respond. Reopen the app."]
        }
        return parsed
    }
}
