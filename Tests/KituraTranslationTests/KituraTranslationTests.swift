import XCTest
import LoggerAPI

@testable import KituraTranslation

class KituraTranslationTests: XCTestCase {

    func testPoImport() {
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
        TranslationBank.settings!.lang = "x-pseudo"
        let psTrans = "Hello!".t()
        XCTAssertEqual(psTrans, "[!!! Ӊëľľѻ! !!!]", "Pseudolocalization failed (got \"\(psTrans)\".")
    }

    static var allTests = [
        ("testPoImport", testPoImport),
    ]
}
