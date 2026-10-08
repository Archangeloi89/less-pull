//
//  SafariWebExtensionHandler.swift
//  Less Pull for Safari Extension
//
//  Forwards the extension's messages to the Less Pull app over its local socket,
//  with the same framing LessPullBrowserHost uses for Chrome, Brave and Firefox:
//  a 4-byte little-endian length followed by JSON. Safari identifies the
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

    static var socketPath: String {
        // The same path BrowserBridge uses. Resolved from the real home directory,
        // which is also the sandbox container's parent when the extension is sandboxed.
        let home = (getpwuid(getuid())?.pointee.pw_dir).map { String(cString: $0) } ?? NSHomeDirectory()
        return home + "/Library/Application Support/Less Pull/browser.sock"
    }

    static func send(_ message: [String: Any]) -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(message), let data = try? JSONSerialization.data(withJSONObject: message) else {
            return ["ok": false, "error": "Invalid message"]
        }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return ["ok": false, "error": "Open Less Pull on this Mac, then try again."] }
        defer { close(fd) }
        var timeout = timeval(tv_sec: 4, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = socketPath
        let fits = withUnsafeMutablePointer(to: &address.sun_path) { pointer -> Bool in
            let capacity = MemoryLayout.size(ofValue: pointer.pointee)
            return path.utf8CString.withUnsafeBufferPointer { bytes in
                guard bytes.count <= capacity else { return false }
                pointer.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
                    for (index, byte) in bytes.enumerated() { destination[index] = byte }
                }
                return true
            }
        }
        guard fits else { return ["ok": false, "error": "Invalid socket path"] }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard connected == 0 else { return ["ok": false, "error": "Open Less Pull on this Mac, then try again."] }
        var size = UInt32(data.count).littleEndian
        guard transfer(fd, &size, 4, writing: true), transfer(fd, data, writing: true) else {
            return ["ok": false, "error": "Less Pull did not respond. Reopen the app."]
        }
        var replySize: UInt32 = 0
        guard transfer(fd, &replySize, 4, writing: false) else { return ["ok": false, "error": "Less Pull did not respond. Reopen the app."] }
        replySize = UInt32(littleEndian: replySize)
        guard replySize > 0, replySize <= 65536 else { return ["ok": false, "error": "Less Pull did not respond. Reopen the app."] }
        var buffer = Data(count: Int(replySize))
        let read = buffer.withUnsafeMutableBytes { raw -> Bool in transfer(fd, raw.baseAddress!, Int(replySize), writing: false) }
        guard read, let parsed = try? JSONSerialization.jsonObject(with: buffer) as? [String: Any] else {
            return ["ok": false, "error": "Less Pull did not respond. Reopen the app."]
        }
        return parsed
    }

    private static func transfer(_ fd: Int32, _ data: Data, writing: Bool) -> Bool {
        data.withUnsafeBytes { raw in transfer(fd, UnsafeMutableRawPointer(mutating: raw.baseAddress!), data.count, writing: writing) }
    }

    private static func transfer(_ fd: Int32, _ pointer: UnsafeMutableRawPointer, _ count: Int, writing: Bool) -> Bool {
        var remaining = count
        var cursor = pointer
        while remaining > 0 {
            let moved = writing ? write(fd, cursor, remaining) : Darwin.read(fd, cursor, remaining)
            if moved <= 0 { return false }
            remaining -= moved
            cursor += moved
        }
        return true
    }
}
