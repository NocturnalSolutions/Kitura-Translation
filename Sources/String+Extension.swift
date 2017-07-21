import Foundation

extension String {

    /// Translate a string.
    ///
    /// - Parameter placeholders: Placeholder values, keyed by placeholder
    ///   name.
    /// - Parameter context: The context string, if any.
    public func t(_ placeholders: [String : String], context: String? = nil) -> String {
        var translated: String = self.t(context)

        for (from, to) in placeholders {
            translated = translated.replacingOccurrences(of: from, with: to)
        }

        return translated
    }

    /// Translate a string.
    ///
    /// - Parameter context: The context string, if any.
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
