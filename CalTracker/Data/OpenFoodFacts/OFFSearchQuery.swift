import Foundation

/// Builds the `q` parameter for Open Food Facts' Search-a-licious service.
///
/// Filters are clauses in the query itself, such as `countries_tags:"en:india"`. The person's text stays outside
/// any parentheses: Search-a-licious ranks bare words as a full-text search, but a parenthesized group becomes an
/// exact filter that matches almost nothing.
nonisolated enum OFFSearchQuery {
    /// Characters removed from the person's text when clauses follow it, so it can't open a group, a phrase or a field filter.
    static let reservedCharacters: Set<Character> = ["\"", "(", ")", "\\", ":"]

    /// Returns `q` for `query` narrowed by `filters`.
    ///
    /// With no filters that Open Food Facts supports, the text is sent unchanged.
    static func text(for query: String, filters: FoodSearchFilters) -> String {
        let clauses = clauses(for: filters)
        guard clauses.isEmpty == false else { return query }

        let words = String(query.map { reservedCharacters.contains($0) ? " " : $0 })
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return ([words] + clauses).filter { $0.isEmpty == false }.joined(separator: " ")
    }

    /// Returns the Open Food Facts tag for `brand`, such as "lay-s" for "Lay's".
    ///
    /// Tags are lowercase with accents removed, and every run of other characters becomes one hyphen.
    static func tag(for brand: String) -> String {
        let folded = brand
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
        var tag = ""
        var needsHyphen = false
        for character in folded {
            if character.isLetter || character.isNumber {
                if needsHyphen, tag.isEmpty == false {
                    tag.append("-")
                }
                needsHyphen = false
                tag.append(character)
            } else {
                needsHyphen = true
            }
        }
        return tag
    }

    /// The country and brand clauses for `filters`, in that order.
    private static func clauses(for filters: FoodSearchFilters) -> [String] {
        var clauses: [String] = []
        if let regionCode = filters.activeRegionCode, let country = OFFCountry.tag(forRegionCode: regionCode) {
            clauses.append(#"countries_tags:"\#(country)""#)
        }
        switch filters.brand {
        case .tag(let tag, _):
            let tag = quotable(tag)
            if tag.isEmpty == false {
                clauses.append(#"brands_tags:"\#(tag)""#)
            }
        case .name(let name):
            // A typed brand may not match a tag exactly, so it also matches the brand as written.
            let tag = tag(for: name)
            let name = quotable(name).trimmingCharacters(in: .whitespaces)
            if tag.isEmpty == false {
                clauses.append(#"(brands_tags:"\#(tag)" OR brands:"\#(name)")"#)
            } else if name.isEmpty == false {
                // Punctuation-only names have no tag.
                clauses.append(#"brands:"\#(name)""#)
            }
        case nil:
            break
        }
        return clauses
    }

    /// `text` without the characters that would end a quoted phrase early.
    private static func quotable(_ text: String) -> String {
        String(text.filter { $0 != "\"" && $0 != "\\" })
    }
}
