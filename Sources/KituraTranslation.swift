import Foundation
import LoggerAPI
import Dispatch

/// A struct to store settings for Translation.
public struct TranslationSettings {

    /// How are translations stored?
    /// - Todo: A Redis method?
    public enum StoreMode {
        /// Always load translations from PO files. Good for testing PO files
        /// while editing them.
        case AlwaysFromFile
        /// Load translations from PO files, then store them in memory.
        case Memory
    }

    /// The language code.
    public var lang: String
    /// The directory PO files are stored in.
    let poDir: String
    /// The translation storage mode.
    /// - SeeAlso: StoreMode
    let storeMode: StoreMode

    public init(lang: String, poDir: String, storeMode: StoreMode = .Memory) {
        self.lang = lang
        self.poDir = poDir
        self.storeMode = storeMode
    }
}

/// The primary Kitura Translation static class.
public class Translation {

    /// Enumeration of possible errors.
    enum TranslationError: Error {
        /// Trying to use the class before settings have been set.
        case NoSettings
    }

    /// Stores the current settings
    public static var settings: TranslationSettings!

    /// An array of the translations by language codes.
    static var store: [String : [String : String]?] = [:]
    /// A semaphore to make sure we're not loading from more than one PO file
    /// at once.
    static var poLoadLock = DispatchSemaphore(value: 1)

    /// Get a translation.
    ///
    /// - Parameter string: The string to get a translation for.
    /// - Parameter context: The context string, if any, to get a translation
    ///   for.
    /// - Throws: TranslationError
    public class func getT(string: String, context: String?) throws -> String? {
        guard settings != nil else {
            Log.error("Set settings before attempting translation!")
            throw TranslationError.NoSettings
        }
        let lang = settings.lang

        if lang == "x-pseudo" {
            return pseudolocalize(string)
        }

        let key = buildKey(string: string, context: context)

        if poLoadLock.wait(timeout: .now() + .seconds(5)) == .timedOut {
            Log.warning("Timed out attempting to load translations for \(lang).")
            return string
        }
        if store[lang] == nil {
            Translation.importTranslations()
        }
        poLoadLock.signal()

        if let byLang = store[lang] {
            if byLang![key] != nil {
                // Hit found.
                if settings.storeMode != .Memory {
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

    /// Store a translation.
    ///
    /// - Parameter string: The string being translated.
    /// - Parameter context: The context string, if any.
    /// - Parameter translation: The translated string.
    class func setT(string: String, context: String?, translation: String) {
        let key = Translation.buildKey(string: string, context: context)
        let lang = Translation.settings.lang
        if Translation.store[lang] == nil {
            Translation.store[lang] = [key: translation]
        }
        else {
            // Not clear why two exclamation points are needed here
            Translation.store[lang]!![key] = translation
        }
    }

    /// Build the key translations are stored by.
    ///
    /// Keys are built from the string being translated concatenated with the
    /// context string, and max out at 256 characters long.
    ///
    /// - Parameter string: The string being translated.
    /// - Parameter context: The context string, if any.
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

    /// Import translations from PO files for the current language.
    class func importTranslations() {
        let lang = Translation.settings.lang
        let langDirPath = Translation.settings.poDir + "/" + lang
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

    /// Parse a PO file.
    ///
    /// - Parameter atPath: The URL of the PO file to import translations from.
    class func parsePo(atPath: URL) {
        guard let fileContentData = try? Data(contentsOf: atPath) else {
            Log.error("Couldn't read PO file \(atPath.absoluteString); skipping.")
            return
        }
        Log.info("Parsing PO file \(atPath.absoluteString).")
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

    /// Pseudolocalize a string, for testing user interfaces and such.
    ///
    /// See https://en.wikipedia.org/wiki/Pseudolocalization for more
    /// information about pseudolocalization.
    static public func pseudolocalize(_ string: String) -> String {
        // Substitution table from https://github.com/eirikRude/pseudolocalizer/blob/master/pseudo.js
        // (MIT licensed)
        let charTable: [String: String] = [
            "A": "Å",
            "B": "Ƀ",
            "C": "Č",
            "D": "Ɖ",
            "E": "Ǝ",
            "F": "Ƒ",
            "G": "Ǥ",
            "H": "Ӊ",
            "I": "Ì",
            "J": "Ĵ",
            "K": "Ӄ",
            "L": "Ĺ",
            "M": "Ӎ",
            "N": "Ń",
            "O": "ϴ",
            "P": "Ƥ",
            "Q": "Ϙ",
            "R": "Я",
            "S": "Ƨ",
            "T": "Ť",
            "U": "Ų",
            "V": "Ʋ",
            "W": "Ŵ",
            "X": "Ӿ",
            "Y": "Ỵ",
            "Z": "Ƶ",
            "a": "ą",
            "b": "Ƃ",
            "c": "č",
            "d": "ď",
            "e": "ë",
            "f": "ḟ",
            "g": "ḡ",
            "h": "ḧ",
            "i": "ἳ",
            "j": "ĵ",
            "k": "ķ",
            "l": "ľ",
            "m": "ṁ",
            "n": "ņ",
            "o": "ѻ",
            "p": "ҏ",
            "q": "ɖ",
            "r": "ȑ",
            "s": "ᶊ",
            "t": "ț",
            "u": "ữ",
            "v": "ѷ",
            "w": "ŵ",
            "x": "ӿ",
            "y": "ŷ",
            "z": "ȥ"
        ]

        var translated = string

        charTable.forEach({key, value in
            translated = translated.replacingOccurrences(of: key, with: value)
        })
        
        return "[!!! " + translated + " !!!]"
        
    }
}
