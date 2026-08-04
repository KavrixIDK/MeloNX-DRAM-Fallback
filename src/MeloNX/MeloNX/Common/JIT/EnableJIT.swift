//
//  EnableJIT.swift
//  MeloNX
//
//  Created by Stossy11 on 3/5/2026.
//

import UIKit

enum JITProvider: String, Identifiable, CaseIterable {
    case disabled = "None"
    case stosdebug = "StosDebug"
    case stosdebugLC = "StosDebug (LC)"
    case stikdebug = "StikDebug"
    case stikdebugLC = "StikDebug (LC)"
    case trollstore = "TrollStore"
    
    var id: String { rawValue }
    
    var displayName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
    
    var isLC: Bool {
        rawValue.hasSuffix("(LC)")
    }
}

class EnableJIT {
    private static var provider: JITProvider?
    private static let bundle = Bundle.main.hostBundleIdentifier!
    
    private static func openURL(_ url: URL) {
        defer { provider = nil }
        let uiApplication = UIApplication.shared
        
        if provider?.isLC == true, let base64 = url.absoluteString.toBase64URLSafe() {
            let liveContainer = URL(string: "livecontainer://open-web-page?url=\(base64)")!
            uiApplication.open(liveContainer, options: [:], completionHandler: nil)
            return
        }
        
        uiApplication.open(url, options: [:], completionHandler: nil)
    }
    
    static func enableJIT(_ prov: String) {
        enableJIT(JITProvider(rawValue: prov) ?? .disabled)
    }
    
    static func enableJIT(_ provider: JITProvider) {
        self.provider = nil
        guard !RyujinxController.shared.isJITEnabled, provider != .disabled else { return }
        self.provider = provider
        
        switch provider {
        case .stikdebug, .stikdebugLC: enableJITStik()
        case .stosdebug, .stosdebugLC: enableJITStos()
        case .trollstore: enableJITTrollStore()
        default: break
        }
    }
    
    private static func enableJITStos() {
        let urlScheme: String = "stosdebug://enableJIT?bundleId=\(bundle)&appName=MeloNX&pid=\(getpid())"
        guard let launchURL = URL(string: urlScheme) else { return }
        
        openURL(launchURL)
    }
    
    private static func enableJITTrollStore() {
        let urlScheme = "apple-magnifier://enable-jit?bundle-id=\(bundle)"
        guard let launchURL = URL(string: urlScheme), UIApplication.shared.canOpenURL(launchURL) else { return }
        
        openURL(launchURL)
    }
    
    private static func enableJITStik() {
        var urlScheme: String = "stikjit://enable-jit"
        
        let isInLiveContainer = AppEnvironment.shared.isInLiveContainer
        
        if #available(iOS 19.0, *), !ProcessInfo.processInfo.hasTXM {
            let scriptdata = script.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            urlScheme += isInLiveContainer ? "?pid=\(getpid())&script-name=MeloNX" : ("?bundle-id=" + bundle)
            
            urlScheme += "&script-data=\(scriptdata)"
        } else {
            urlScheme += isInLiveContainer ? "?pid=\(getpid())" : "?bundle-id=" + bundle
        }
        
        if let launchURL = URL(string: urlScheme) {
            openURL(launchURL)
        }
    }
}

extension String {
    func toBase64URLSafe() -> String? {
        guard let data = self.data(using: .utf8) else { return nil }
        let base64 = data.base64EncodedString()
        
        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

// Universal Script :333333
fileprivate let script = """
Y29uc3QgQ01EX0RFVEFDSCA9IDA7CmNvbnN0IENNRF9QUkVQQVJFX1JFR0lPTiA9IDE7CmNvbnN0IENNRF9ORVdfQlJFQUtQT0lOVFMgPSAyOwpjb25zdCBjb21tYW5kcyA9IHsKICAgIFtDTURfREVUQUNIXTogSklUMjZEZXRhY2gsCiAgICBbQ01EX1BSRVBBUkVfUkVHSU9OXTogSklUMjZQcmVwYXJlUmVnaW9uLAogICAgW0NNRF9ORVdfQlJFQUtQT0lOVFNdOiBKSVQyNk5ld0JyZWFrcG9pbnRzCn07CmNvbnN0IGxlZ2FjeUNvbW1hbmRzID0gewogICAgWzB4NjhdOiBKSVQyNk5ld0JyZWFrcG9pbnRzLAogICAgWzB4NjldOiBKSVQyNkhhbmRsZUJyazB4NjksCiAgICBbMHhmMDBkXTogSklUMjZIYW5kbGVCcmsweGYwMGQKfTsKCmxldCB0aWQsIHgwLCB4MSwgeDE2LCBwYzsKCmxldCBkZXRhY2hlZCA9IGZhbHNlOwpsZXQgcGlkID0gZ2V0X3BpZCgpOwpsb2coYHBpZCA9ICR7cGlkfWApOwpsZXQgYXR0YWNoUmVzcG9uc2UgPSBzZW5kX2NvbW1hbmQoYHZBdHRhY2g7JHtwaWQudG9TdHJpbmcoMTYpfWApOwpsb2coYGF0dGFjaF9yZXNwb25zZSA9ICR7YXR0YWNoUmVzcG9uc2V9YCk7CiAgICAKbGV0IHRvdGFsQnJlYWtwb2ludHMgPSAwOwp3aGlsZSAoIWRldGFjaGVkKSB7CiAgICB0b3RhbEJyZWFrcG9pbnRzKys7CiAgICBsb2coYEhhbmRsaW5nIGJyZWFrcG9pbnQgJHt0b3RhbEJyZWFrcG9pbnRzfWApOwogICAgCiAgICBsZXQgYnJrUmVzcG9uc2UgPSBzZW5kX2NvbW1hbmQoYGNgKTsKICAgIGxvZyhgYnJrUmVzcG9uc2UgPSAke2Jya1Jlc3BvbnNlfWApOwogICAgCiAgICBsZXQgdG1wTWF0Y2ggPSAvVFswLTlhLWZdK3RocmVhZDooPzx0aWQ+WzAtOWEtZl0rKTsvLmV4ZWMoYnJrUmVzcG9uc2UpOwogICAgdGlkID0gdG1wTWF0Y2ggPyB0bXBNYXRjaC5ncm91cHNbJ3RpZCddIDogbnVsbDsKICAgIHRtcE1hdGNoID0gLzIwOig/PHJlZz5bMC05YS1mXXsxNn0pOy8uZXhlYyhicmtSZXNwb25zZSk7CiAgICBwYyA9IHRtcE1hdGNoID8gdG1wTWF0Y2guZ3JvdXBzWydyZWcnXSA6IG51bGw7CiAgICB0bXBNYXRjaCA9IC8xMDooPzxyZWc+WzAtOWEtZl17MTZ9KTsvLmV4ZWMoYnJrUmVzcG9uc2UpOwogICAgeDE2ID0gdG1wTWF0Y2ggPyB0bXBNYXRjaC5ncm91cHNbJ3JlZyddIDogbnVsbDsKICAgIGlmICghdGlkIHx8ICFwYyB8fCAheDE2KSB7CiAgICAgICAgbG9nKGBGYWlsZWQgdG8gZXh0cmFjdCByZWdpc3RlcnM6IHRpZD0ke3RpZH0sIHBjPSR7cGN9LCB4MTY9JHt4MTZ9YCk7CiAgICAgICAgY29udGludWU7CiAgICB9CiAgICBwYyA9IGxpdHRsZUVuZGlhbkhleFN0cmluZ1RvTnVtYmVyKHBjKTsKICAgIHgxNiA9IGxpdHRsZUVuZGlhbkhleFN0cmluZ1RvTnVtYmVyKHgxNik7CiAgICAKICAgIGxldCBpbnN0cnVjdGlvblJlc3BvbnNlID0gc2VuZF9jb21tYW5kKGBtJHtwYy50b1N0cmluZygxNil9LDRgKTsKICAgIGxvZyhgaW5zdHJ1Y3Rpb24gYXQgcGM6ICR7aW5zdHJ1Y3Rpb25SZXNwb25zZX1gKTsKICAgIGxldCBpbnN0clUzMiA9IGxpdHRsZUVuZGlhbkhleFRvVTMyKGluc3RydWN0aW9uUmVzcG9uc2UpOwogICAgbGV0IGJya0ltbWVkaWF0ZSA9IGV4dHJhY3RCcmtJbW1lZGlhdGUoaW5zdHJVMzIpOwogICAgbG9nKGBCUksgaW1tZWRpYXRlOiAweCR7YnJrSW1tZWRpYXRlLnRvU3RyaW5nKDE2KX0gKCR7YnJrSW1tZWRpYXRlfSlgKTsKICAgIGlmIChsZWdhY3lDb21tYW5kc1ticmtJbW1lZGlhdGVdICE9IHVuZGVmaW5lZCkgewogICAgICAgIC8vIHdoZW4gd2UgZmluZCBhIHZhbGlkIGJyayBpbW1lZGlhdGUgY29tbWFuZCwgcGFyc2UgeDAgYW5kIHgxCiAgICAgICAgdG1wTWF0Y2ggPSAvMDA6KD88cmVnPlswLTlhLWZdezE2fSk7Ly5leGVjKGJya1Jlc3BvbnNlKTsKICAgICAgICB4MCA9IHRtcE1hdGNoID8gdG1wTWF0Y2guZ3JvdXBzWydyZWcnXSA6IG51bGw7CiAgICAgICAgdG1wTWF0Y2ggPSAvMDE6KD88cmVnPlswLTlhLWZdezE2fSk7Ly5leGVjKGJya1Jlc3BvbnNlKTsKICAgICAgICB4MSA9IHRtcE1hdGNoID8gdG1wTWF0Y2guZ3JvdXBzWydyZWcnXSA6IG51bGw7CiAgICAgICAgaWYgKCF4MCB8fCAheDEpIHsKICAgICAgICAgICAgbG9nKGBGYWlsZWQgdG8gZXh0cmFjdCByZWdpc3RlcnM6IHgwPSR7eDB9LCB4MT0ke3gxfWApOwogICAgICAgICAgICBjb250aW51ZTsKICAgICAgICB9CiAgICAgICAgeDAgPSBsaXR0bGVFbmRpYW5IZXhTdHJpbmdUb051bWJlcih4MCk7CiAgICAgICAgeDEgPSBsaXR0bGVFbmRpYW5IZXhTdHJpbmdUb051bWJlcih4MSk7CiAgICAgICAgCiAgICAgICAgLy8ganVtcCBvdmVyIGJyawogICAgICAgIGxldCBwY1BsdXM0ID0gbnVtYmVyVG9MaXR0bGVFbmRpYW5IZXhTdHJpbmcocGMgKyA0bik7CiAgICAgICAgbGV0IHBjUGx1czRSZXNwb25zZSA9IHNlbmRfY29tbWFuZChgUDIwPSR7cGNQbHVzNH07dGhyZWFkOiR7dGlkfTtgKTsKICAgICAgICBsb2coYHBjUGx1czRSZXNwb25zZSA9ICR7cGNQbHVzNFJlc3BvbnNlfWApOwogICAgICAgIAogICAgICAgIC8vIGRpc3BhdGNoIGJyay1pbW1lZGlhdGUgY29tbWFuZAogICAgICAgIGNvbnN0IGNvbW1hbmQgPSBsZWdhY3lDb21tYW5kc1ticmtJbW1lZGlhdGVdOwogICAgICAgIGNvbW1hbmQoYnJrUmVzcG9uc2UpOwogICAgfSBlbHNlIHsKICAgICAgICBsb2coYFNraXBwaW5nIGJyZWFrcG9pbnQ6IGJyayBpbW1lZGlhdGUgMHgke2Jya0ltbWVkaWF0ZS50b1N0cmluZygxNil9IHdhcyBub3QgaGFuZGxlZCBieSB0aGlzIHNjcmlwdC4gWW91IGNvdWxkIGFkZCBpdCBieSBldmFsdWF0aW5nIGxlZ2FjeUNvbW1hbmRzWzB4JHticmtJbW1lZGlhdGUudG9TdHJpbmcoMTYpfV0gPSB5b3VyRnVuY3Rpb247YCk7CiAgICAgICAgY29udGludWU7CiAgICB9Cn0KCmZ1bmN0aW9uIEpJVDI2RGV0YWNoKCkgewogICAgbGV0IGRldGFjaFJlc3BvbnNlID0gc2VuZF9jb21tYW5kKGBEYCk7CiAgICBsb2coYGRldGFjaFJlc3BvbnNlID0gJHtkZXRhY2hSZXNwb25zZX1gKTsKICAgIGRldGFjaGVkID0gdHJ1ZTsKfQoKLy8gYnJrIDB4NjgKZnVuY3Rpb24gSklUMjZOZXdCcmVha3BvaW50cyhicmtSZXNwb25zZSkgewogICAgbGV0IGluc3RydWN0aW9uUmVzcG9uc2UgPSBzZW5kX2NvbW1hbmQoYG0ke3BjLnRvU3RyaW5nKDE2KX0sNGApOwogICAgbG9nKGBpbnN0cnVjdGlvbiBhdCBwYzogJHtpbnN0cnVjdGlvblJlc3BvbnNlfWApOwogICAgbGV0IGluc3RyVTMyID0gbGl0dGxlRW5kaWFuSGV4VG9VMzIoaW5zdHJ1Y3Rpb25SZXNwb25zZSk7CiAgICBsZXQgYnJrSW1tZWRpYXRlID0gZXh0cmFjdEJya0ltbWVkaWF0ZShpbnN0clUzMik7CiAgICAKICAgIGxldCBtZW1SZXNwb25zZSA9IHNlbmRfY29tbWFuZChgbSR7eDAudG9TdHJpbmcoMTYpfSwke3gxfWApOwoKICAgIGxldCBzY3JpcHRUZXh0ID0gaGV4VG9Bc2NpaShtZW1SZXNwb25zZSk7CiAgICBsb2coYFNjcmlwdCB0ZXh0OiAke3NjcmlwdFRleHR9YCk7CgogICAgY29uc3QgcmVzID0gcnVuU2NyaXB0QW5kQ2FwdHVyZShzY3JpcHRUZXh0KTsKICAgIGlmIChyZXMub2spIHsKICAgICAgICBsb2coJ1NjcmlwdCBzdWNjZWVkZWQ6JywgcmVzLnZhbHVlKTsKICAgIH0gZWxzZSB7CiAgICAgICAgbG9nKCdTY3JpcHQgZmFpbGVkOicsIHJlcy5uYW1lLCByZXMubWVzc2FnZSk7CiAgICAgICAgbG9nKHJlcy5zdGFjayk7CiAgICB9Cn0KCi8vIGJyayAweDY5CmZ1bmN0aW9uIEpJVDI2SGFuZGxlQnJrMHg2OShicmtSZXNwb25zZSkgewogICAgbGV0IHB1dFgwUmVzcG9uc2UgPSBzZW5kX2NvbW1hbmQoYFAwPUUwMDAwMDY5O3RocmVhZDoke3RpZH07YCk7CiAgICBsb2coYHB1dFgwUmVzcG9uc2UgPSAke3B1dFgwUmVzcG9uc2V9YCk7Cn0KCi8vIGJyayAweGYwMGQKZnVuY3Rpb24gSklUMjZIYW5kbGVCcmsweGYwMGQoYnJrUmVzcG9uc2UpIHsKICAgIC8vIGRpc3BhdGNoIGNvbW1hbmQgdmlhIHgxNgogICAgY29uc3QgY29tbWFuZCA9IGNvbW1hbmRzW3gxNl07CiAgICBpZiAoY29tbWFuZCA9PT0gdW5kZWZpbmVkKSB7CiAgICAgICAgbG9nKGBVbmtub3duIGNvbW1hbmQgJHt4MTYudG9TdHJpbmcoMTYpfWApOwogICAgICAgIHJldHVybjsKICAgIH0KICAgIGxvZyhgSW52b2tpbmcgY29tbWFuZCAke3gxNi50b1N0cmluZygxNil9YCk7CiAgICBjb21tYW5kKGJya1Jlc3BvbnNlKTsKfQoKZnVuY3Rpb24gSklUMjZQcmVwYXJlUmVnaW9uKGJya1Jlc3BvbnNlKSB7CiAgICBsZXQgaW5zdHJ1Y3Rpb25SZXNwb25zZSA9IHNlbmRfY29tbWFuZChgbSR7cGMudG9TdHJpbmcoMTYpfSw0YCk7CiAgICBsb2coYGluc3RydWN0aW9uIGF0IHBjOiAke2luc3RydWN0aW9uUmVzcG9uc2V9YCk7CiAgICBsZXQgaW5zdHJVMzIgPSBsaXR0bGVFbmRpYW5IZXhUb1UzMihpbnN0cnVjdGlvblJlc3BvbnNlKTsKICAgIGxldCBicmtJbW1lZGlhdGUgPSBleHRyYWN0QnJrSW1tZWRpYXRlKGluc3RyVTMyKTsKICAgIAogICAgaWYgKHgwID09IDBuICYmIHgxID09IDBuKSB7CiAgICAgICAgcmV0dXJuOwogICAgfQoKICAgIGxldCBqaXRQYWdlQWRkcmVzcyA9IHgwOwogICAgaWYgKHgwID09IDBuKSB7CiAgICAgICAgbGV0IHJlcXVlc3RSWFJlc3BvbnNlID0gc2VuZF9jb21tYW5kKGBfTSR7eDEudG9TdHJpbmcoMTYpfSxyeGApOwogICAgICAgIGxvZyhgcmVxdWVzdFJYUmVzcG9uc2UgPSAke3JlcXVlc3RSWFJlc3BvbnNlfWApOwogICAgICAgIAogICAgICAgIGlmICghcmVxdWVzdFJYUmVzcG9uc2UgfHwgcmVxdWVzdFJYUmVzcG9uc2UubGVuZ3RoID09PSAwKSB7CiAgICAgICAgICAgIGxvZyhgRmFpbGVkIHRvIGFsbG9jYXRlIFJYIG1lbW9yeWApOwogICAgICAgICAgICByZXR1cm47CiAgICAgICAgfQogICAgICAgIAogICAgICAgIGppdFBhZ2VBZGRyZXNzID0gQmlnSW50KGAweCR7cmVxdWVzdFJYUmVzcG9uc2V9YCk7CiAgICAgICAgbG9nKGBBbGxvY2F0ZWQgSklUIHBhZ2UgYXQgYWRkcmVzczogMHgke2ppdFBhZ2VBZGRyZXNzLnRvU3RyaW5nKDE2KX1gKTsKICAgIH0KCiAgICBsZXQgcHJlcGFyZUpJVFBhZ2VSZXNwb25zZSA9IHByZXBhcmVfbWVtb3J5X3JlZ2lvbihqaXRQYWdlQWRkcmVzcywgeDEpOwogICAgbG9nKGBwcmVwYXJlSklUUGFnZVJlc3BvbnNlID0gJHtwcmVwYXJlSklUUGFnZVJlc3BvbnNlfWApOwoKICAgIGxldCBwdXRYMFJlc3BvbnNlID0gc2VuZF9jb21tYW5kKGBQMD0ke251bWJlclRvTGl0dGxlRW5kaWFuSGV4U3RyaW5nKGppdFBhZ2VBZGRyZXNzKX07dGhyZWFkOiR7dGlkfTtgKTsKICAgIGxvZyhgcHV0WDBSZXNwb25zZSA9ICR7cHV0WDBSZXNwb25zZX1gKTsKfQoKLy8gdXRpbGl0aWVzCmZ1bmN0aW9uIGxpdHRsZUVuZGlhbkhleFN0cmluZ1RvTnVtYmVyKGhleFN0cikgewogICAgY29uc3QgYnl0ZXMgPSBbXTsKICAgIGZvciAobGV0IGkgPSAwOyBpIDwgaGV4U3RyLmxlbmd0aDsgaSArPSAyKSB7CiAgICAgICAgYnl0ZXMucHVzaChwYXJzZUludChoZXhTdHIuc3Vic3RyKGksIDIpLCAxNikpOwogICAgfQogICAgbGV0IG51bSA9IDBuOwogICAgZm9yIChsZXQgaSA9IDQ7IGkgPj0gMDsgaS0tKSB7CiAgICAgICAgbnVtID0gKG51bSA8PCA4bikgfCBCaWdJbnQoYnl0ZXNbaV0pOwogICAgfQogICAgcmV0dXJuIG51bTsKfQoKZnVuY3Rpb24gbnVtYmVyVG9MaXR0bGVFbmRpYW5IZXhTdHJpbmcobnVtKSB7CiAgICBjb25zdCBieXRlcyA9IFtdOwogICAgZm9yIChsZXQgaSA9IDA7IGkgPCA1OyBpKyspIHsKICAgICAgICBieXRlcy5wdXNoKE51bWJlcihudW0gJiAweEZGbikpOwogICAgICAgIG51bSA+Pj0gOG47CiAgICB9CiAgICB3aGlsZSAoYnl0ZXMubGVuZ3RoIDwgOCkgewogICAgICAgIGJ5dGVzLnB1c2goMCk7CiAgICB9CiAgICByZXR1cm4gYnl0ZXMubWFwKGIgPT4gYi50b1N0cmluZygxNikucGFkU3RhcnQoMiwgJzAnKSkuam9pbignJyk7Cn0KCmZ1bmN0aW9uIGxpdHRsZUVuZGlhbkhleFRvVTMyKGhleFN0cikgewogICAgcmV0dXJuIHBhcnNlSW50KGhleFN0ci5tYXRjaCgvLi4vZykucmV2ZXJzZSgpLmpvaW4oJycpLCAxNik7Cn0KCmZ1bmN0aW9uIGV4dHJhY3RCcmtJbW1lZGlhdGUodTMyKSB7CiAgICByZXR1cm4gKHUzMiA+PiA1KSAmIDB4RkZGRjsKfQoKZnVuY3Rpb24gaGV4VG9Bc2NpaShoZXhTdHIpIHsKICAgIGxldCBzdHIgPSAnJzsKICAgIGZvciAobGV0IGkgPSAwOyBpIDwgaGV4U3RyLmxlbmd0aDsgaSArPSAyKSB7CiAgICAgICAgY29uc3QgYnl0ZSA9IHBhcnNlSW50KGhleFN0ci5zdWJzdHIoaSwgMiksIDE2KTsKICAgICAgICBpZiAoYnl0ZSA9PT0gMCkgYnJlYWs7IAogICAgICAgIHN0ciArPSBTdHJpbmcuZnJvbUNoYXJDb2RlKGJ5dGUpOwogICAgfQogICAgcmV0dXJuIHN0cjsKfQoKZnVuY3Rpb24gcnVuU2NyaXB0QW5kQ2FwdHVyZShzY3JpcHRUZXh0KSB7CiAgICB0cnkgewogICAgICAgIGNvbnN0IHZhbHVlID0gZXZhbChzY3JpcHRUZXh0KTsKICAgICAgICByZXR1cm4geyBvazogdHJ1ZSwgdmFsdWUgfTsKICAgIH0gY2F0Y2ggKGVycikgewogICAgICAgIHJldHVybiB7CiAgICAgICAgICAgIG9rOiBmYWxzZSwKICAgICAgICAgICAgbmFtZTogZXJyICYmIGVyci5uYW1lLAogICAgICAgICAgICBtZXNzYWdlOiBlcnIgJiYgZXJyLm1lc3NhZ2UsCiAgICAgICAgICAgIHN0YWNrOiBlcnIgJiYgZXJyLnN0YWNrCiAgICAgICAgfTsKICAgIH0KfQ==
"""
