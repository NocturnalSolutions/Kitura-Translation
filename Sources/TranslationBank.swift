import Foundation
import LoggerAPI

class TranslationBank {
    enum StoreMode {
        case AlwaysFromFile, Memory
    }

    enum TranslationBankError: Error {
        case NoSettings
    }

    struct TranslationBankSettings {
        let storeMode: StoreMode = .Memory
        var lang: String
        let poDir: String
    }

    static var settings: TranslationBankSettings?

    static var store: [String : [String : String]?] = [:]

    public class func getT(string: String, context: String?) throws -> String? {
        guard settings != nil else {
            Log.error("Set settings before attempting translation!")
            throw TranslationBankError.NoSettings
        }
        let key = buildKey(string: string, context: context)
        let lang = settings!.lang

        if store[lang] == nil {
            TranslationBank.importTranslations()
        }

        if let byLang = store[lang] {
            if byLang![key] != nil {
                // Hit found.
                if settings!.storeMode != .Memory {
                    let hit = byLang![key]!
                    store[lang] = [:]
                    return hit
                }
                return byLang![key]!
            }
        }

        Log.warning("No translation for key \(key) in lang \(lang).")
        return string
    }

    class func setT(string: String, context: String?, translation: String) {
        let key = TranslationBank.buildKey(string: string, context: context)
        let lang = TranslationBank.settings!.lang
        if TranslationBank.store[lang] == nil {
            TranslationBank.store[lang] = [key: translation]
        }
        else {
            // Not clear why two exclamation points are needed here
            TranslationBank.store[lang]!![key] = translation
        }
    }

    class func buildKey(string: String, context: String?) -> String {
        let mutableContext = context ?? ""
        var key = string + ":" + mutableContext
        if key.characters.count < 256 {
            return key
        }
        let cxLen = mutableContext.characters.count + 1
        let maxLenForKey = 255 - cxLen
        let endIdx = string.index(string.startIndex, offsetBy: maxLenForKey)
        key = string[string.startIndex...endIdx] + ":" + mutableContext
        return key

    }

    class func importTranslations() {
        let lang = TranslationBank.settings!.lang
        let langDirPath = TranslationBank.settings!.poDir + "/" + lang
        var trueObjCBool: ObjCBool = true
        guard FileManager.default.fileExists(atPath: langDirPath, isDirectory: &trueObjCBool) else {
            Log.error("PO language directory \(langDirPath) is not a directory or not readable.")
            return
        }
        let dirEnum = FileManager.default.enumerator(atPath: langDirPath)
        while let filePath = dirEnum?.nextObject() as! String? {
            if filePath.characters.count > 4 && filePath.substring(from: filePath.index(filePath.endIndex, offsetBy: -3)) == ".po" {
                let pathUrl = URL(fileURLWithPath: langDirPath + "/" + filePath)
                parsePo(atPath: pathUrl)
            }
        }
    }

    class func parsePo(atPath: URL) {
        guard let fileContentData = try? Data(contentsOf: atPath) else {
            Log.error("Couldn't read PO file \(atPath.absoluteString); skipping.")
            return
        }
        let poString = String(data: fileContentData, encoding: .utf8)
        // Sanitize line breaks
        let poStringClean = poString?.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let poStringSplit = poStringClean?.components(separatedBy: "\n\n")
        let msgPartPattern = try! NSRegularExpression(pattern: "^msg(id|str|ctxt) \"(.*)\"$", options: [])
        let strContinuePattern = try! NSRegularExpression(pattern: "^\"(.*)\"$", options: [])
        for (idx, poSection) in poStringSplit!.enumerated() {
            let poSectionLines = poSection.components(separatedBy: "\n")
            var msgid: String? = nil
            var msgstr: String? = nil
            var msgctxt: String? = nil
            for line in poSectionLines {
                let lineRange = NSRange(location: 0, length: line.utf16.count)
                if let match = msgPartPattern.firstMatch(in: line, options: [], range: lineRange) {
                    let typeRange = match.rangeAt(1)
                    let start = String.UTF16Index(typeRange.location)
                    let end = String.UTF16Index(typeRange.location + typeRange.length)
                    let type = String(line.utf16[start..<end])
                    let valRange = match.rangeAt(2)
                    let vstart = String.UTF16Index(valRange.location)
                    let vend = String.UTF16Index(valRange.location + valRange.length)
                    let value = String(line.utf16[vstart..<vend])
                    if value != "" {
                        switch type! {
                        case "id":
                            msgid = value
                        case "str":
                            msgstr = value
                        case "ctxt":
                            msgctxt = value
                        default:
                            break
                        }
                    }
                }
                else if let match = strContinuePattern.firstMatch(in: line, options: [], range: lineRange) {
                    let valRange = match.rangeAt(1)
                    let vstart = String.UTF16Index(valRange.location)
                    let vend = String.UTF16Index(valRange.location + valRange.length)
                    let value = String(line.utf16[vstart..<vend])
                    if msgstr == nil {
                        Log.warning("Detected continuing msgstr before initial msgstr definition in section \(idx) of PO file \(atPath.path) (accepting it as a msgstr anyway).")
                        msgstr = value
                    }
                    else {
                        msgstr = msgstr! + value!
                    }
                }
                else if line.characters.first == "#" {
                    // Ignore the comment
                    continue
                }
                else {
                    Log.warning("Unparsable line \"\(line)\" in section \(idx) of PO file \(atPath.path).")
                    continue
                }
            }

            guard msgid != nil else {
                Log.error("Could not find msgid in section \(idx) of PO file \(atPath.path); skipping.")
                continue
            }
            guard msgstr != nil else {
                Log.error("Could not find msgstr in section \(idx) of PO file \(atPath.path); skipping.")
                continue
            }
//            guard msgctxt != nil else {
//                Log.error("Could not find msgctxt in section \(idx) of PO file \(atPath.path); skipping.")
//                continue
//            }

            setT(string: msgid!, context: msgctxt, translation: msgstr!)

        }
    }
}
