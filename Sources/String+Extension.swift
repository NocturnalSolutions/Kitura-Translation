import Foundation

extension String {
    public func t(_ placeholders: [String : String], context: String? = nil) -> String {
        var translated: String = self.t(context)

        for (from, to) in placeholders {
            translated = translated.replacingOccurrences(of: from, with: to)
        }

        return translated
    }

    public func t(_ context: String? = nil) -> String {
        do {
            let translated = try TranslationBank.getT(string: self, context: context)
            return translated ?? self
        }
        catch TranslationBank.TranslationBankError.NoSettings {
            return self
        }
        catch {
            return self
        }
    }

}
