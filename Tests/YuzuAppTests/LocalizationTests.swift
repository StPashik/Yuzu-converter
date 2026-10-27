import XCTest
import AppKit
@testable import YuzuApp

final class LocalizationTests: XCTestCase {
    func testCompactActionLabelsFitTheirWheelButtons() {
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        for language in AppLanguage.allCases {
            for key in ["AirDrop", "Float", "Copy", "Move", "Copy Path", "Terminal", "ZIP"] {
                let title = L10n.string(key, language: language)
                let width = (title as NSString).size(withAttributes: [.font: font]).width
                XCTAssertLessThanOrEqual(width, 70, "\(language.rawValue): \(title)")
            }
        }
    }

    private func table(_ language: AppLanguage) throws -> [String: String] {
        let bundle = try XCTUnwrap(L10n.resourceBundle(for: language))
        let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
        let value = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try XCTUnwrap(value as? [String: String])
    }

    func testEveryLanguageHasTheSameKeysAndFormattingArguments() throws {
        let english = try table(.english)
        XCTAssertEqual(AppLanguage.allCases.count, 5)
        let placeholder = try NSRegularExpression(pattern: #"(?<!%)%(?:@|ld|d)"#)
        func placeholders(_ text: String) -> [String] {
            placeholder.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                (text as NSString).substring(with: $0.range)
            }
        }
        for language in AppLanguage.allCases {
            let translated = try table(language)
            XCTAssertEqual(Set(translated.keys), Set(english.keys), language.rawValue)
            for (key, value) in english {
                let localized = try XCTUnwrap(translated[key])
                XCTAssertFalse(localized.isEmpty)
                XCTAssertEqual(placeholders(localized), placeholders(value), "\(language.rawValue): \(key)")
            }
        }
    }

    func testNativeNamesFallbackAndInterpolatedUserData() {
        XCTAssertEqual(AppLanguage.english.name, "English")
        for language in AppLanguage.allCases {
            if language != .english {
                XCTAssertNotEqual(L10n.string("Settings…", language: language), "Settings…")
            }
            XCTAssertEqual(L10n.string("Missing English key", language: language), "Missing English key")
            XCTAssertTrue(L10n.string("Converting to %@", language: language, arguments: ["PNG"]).contains("PNG"))
            XCTAssertTrue(L10n.string("%ld files", language: language, arguments: [3]).contains("3"))
            let filename = "photo 100% café.png"
            XCTAssertTrue(L10n.string("Choose “%@”. Converted files are saved beside the original.",
                                       language: language, arguments: [filename]).contains(filename))
        }
    }
}
