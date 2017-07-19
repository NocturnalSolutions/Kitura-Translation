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
            let translated = try Translation.getT(string: self, context: context)
            return translated ?? self
        }
        catch Translation.TranslationError.NoSettings {
            return self
        }
        catch {
            return self
        }
    }

}
