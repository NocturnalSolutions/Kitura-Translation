# Kitura Translation

*Warning: This project is still in an experimental state.* Be prepared for API changes to occur without warning, and let's not even get started about bugs.

Kitura Translation allows for [Kitura](http://www.kitura.io) web sites to present content in different languages. Translations are stored in industry-standard PO files.

(Kitura Translation does not strictly depend on Kitura and theoretically could be used without it, but it is intended to be used with Kitura primarily.)

## Usage

Aside from the documentation below, please have a look at my [Kitura i18n Sample](https://github.com/NocturnalSolutions/Kitura-i18nSample) project which uses Kitura Translation along with [Kitura Language Negotiation](https://github.com/NocturnalSolutions/Kitura-LanguageNegotiation) to demonstrate a site with basic i18n (internationalization) features.

Kitura Translation expects translations to be stored in [PO files](https://www.gnu.org/savannah-checkouts/gnu/gettext/manual/html_node/PO-Files.html). They basically look like this:

```
msgid "Hello!"
msgstr "¡Hola!"

msgid "Goodbye."
msgstr "Adiós."
```

That is, the `msgid` line contains the untranslated text (which is typically in English, but can in reality be anything, including a code such as `MSG-HELLO` or something like that), and the `msgstr` line contains the translated text. Each entry is separated by a blank line.

You can also use a `msgctxt` line to give context to disambiguate terms where the `msgid` by itself does not give enough information about its usage for translators, or for cases where text may be identical in the source language but will be different in the translation.


```
msgid "Read messages"
msgctxt "Link to take users to their message list page"
msgstr "通信を読む"

msgid "Read messages"
msgctxt "Title of block showing messages that have previously been read"
msgstr "読んだ通信"
```

These PO files should go in a defined translation directory, in a subdirectory named with the language code. The translation directory can be anywhere readable by your app; I like to make it a subdirectory of my Kitura project so that it's stored in version control along with it, but it's up to you. The PO file or files can have any name; so long as it has a `.po` extension, Kitura Translation will try to load translations from it. Here's an example file layout for a site with Japanese, Spanish, and Simplified Chinese translations.

```
Translations
├── ja
│   ├── foo.po
│   ├── bar.po
│   └── baz.po
├── es
│   ├── foo.po
│   ├── bar.po
│   └── baz.po
└── zh-hans
    ├── foo.po
    ├── bar.po
    └── baz.po
```

If you do keep your Translations directory in your project directory as mentioned above, here's a trick to find a path to that directory:

```swift
let poDir = URL(fileURLWithPath: #file + "/../../Translations").standardizedFileURL.path
```

Depend on how deep in your project directory the source file is, you may have to add more `../`s.

Anyway, now that you have a directory of translations, here's how to use it:

```swift
// Build a settings object first, with the "es" (Spanish) language code.
let settings = TranslationSettings(lang: "es", poDir: poDir)

Translation.settings = settings

// Now let's translate a string. This is done by using the t() extension
// function on a string.
response.send("Hello!".t())
// If all goes well, "¡Hola!" is sent.

// Now let's get the Japanese translation.
Translation.settings!.lang = "ja"
response.send("Hello!".t())
// Now "こんにちは！" is sent.

// Pass a `context` parameter if needed.
response.send("Read messages".t(context: "Link to take users to their message list page"))
```

If you don't have translations ready yet but still want to play with Kitura Translation, set the language code to `x-pseudo`, and Kitura Translation will [pseudolocalize](https://en.wikipedia.org/wiki/Pseudolocalization) the string.

```swift
let settings = TranslationSettings(lang: "x-pseudo", poDir: ".")
response.send("Hello!".t())
// Sends "[!!! Ӊëľľѻ! !!!]"
```

You can use placeholders for values that may vary in translations. Pass a `placeholders` parameter with a `[String: String]` dictionary with the keys being the placeholder names (which can be anything) and the values being the values to replace. 

```swift
let msgCount = getUnreadMsgCountSomehow()

switch msgCount {
    case 0:
        response.send("You have no messages.".t())
    case 1:
        response.send("You have one message.".t())
    default:
        let placeholders = ["%COUNT": String(msgCount)]
        response.send("You have %COUNT messages.".t(placeholders: placeholders))
}

// Note that doing it this way is wrong because the structure of the
// translation in the destination language cannot always be predicted.
response.send("You have ".t() + msgCount + " messages.".t()) // DON'T DO THIS!

```

And your PO files would look something like this:


```
msgid "You have no messages."
msgstr "No está mensajes."

msgid "You have one message."
msgstr "Está uno mensaje."

msgid "You have %COUNT messages."
msgstr "Están %COUNT mensajes."
```

```
msgid "You have no messages."
msgstr "通信がありません。"

msgid "You have one message."
msgstr "通信が一つあります。"

msgid "You have %COUNT messages."
msgstr "通信が%COUNTあります。"
```

(Please correct my Spanish or Japanese if necessary. It's been a while for both of them…)

Thanks for trying Kitura Translation. Please don't hesitate to contact me with questions, bug reports, or feature requests.
