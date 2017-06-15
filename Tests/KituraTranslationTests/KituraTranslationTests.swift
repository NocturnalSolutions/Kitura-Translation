import XCTest
import LoggerAPI
import HeliumLogger

@testable import KituraTranslation

class KituraTranslationTests: XCTestCase {

    func testPoImport() {
        // Trick to make sure logged messages are still visible while tests run
        let se = StandardError()
        HeliumStreamLogger.use(outputStream: se)

        // Note that the po files in this directory are from Apache OpenOffice
        let path = URL(fileURLWithPath: #file + "/../Translations").standardizedFileURL.path
        TranslationBank.settings = TranslationBankSettings(lang: "fr", poDir: path)

        let formatsTrans = "Formats".t()
        XCTAssertTrue(formatsTrans == "Mise en forme", "Translation of \"Formats\" without context failed (got \"\(formatsTrans)\").")
        let acTrans = "AutoCorrect".t("shells.src#STR_REDLINE_TITLE.string.text")
        XCTAssertTrue(acTrans == "AutoCorrection", "Translation of \"AutoCorrect\" with context failed (got \"\(acTrans)\").")
        TranslationBank.settings!.lang = "ja"
        let jaFormatsTrans = "Formats".t()
        XCTAssertTrue(jaFormatsTrans == "属性", "Translation of \"Formats\" to Japanese failed (got \"\(jaFormatsTrans)\").")
        let jaCalWPlaceholders = "%PRODUCTNAME Calendar".t(["%PRODUCTNAME": "バナナ"])
        XCTAssertTrue(jaCalWPlaceholders == "バナナ カレンダー", "Simple placeholders failed (got \"\(jaCalWPlaceholders)\").")
    }

    static var allTests = [
        ("testPoImport", testPoImport),
    ]
}

// Thank you to https://deepswift.com/core/standard-io/ <3
struct StandardError: TextOutputStream {
    func write(_ text: String) {
        guard let data = text.data(using: String.Encoding.utf8) else {
            return
        }
        FileHandle.standardError.write(data)
    }
}
