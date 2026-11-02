/// The Open Food Facts Search-a-licious response, limited to the requested fields.
nonisolated struct OFFSearchResponse: Decodable, Sendable {
    /// The matching products.
    let products: [Product]

    /// The page these products are on, starting at 1.
    let page: Int?

    /// How many pages of results there are.
    let pageCount: Int?

    /// The most common brand tags for the query and filters, when facets were requested.
    ///
    /// It can include OFF's `--other--` bucket, which counts every remaining brand.
    let brandFacets: [FacetItem]

    private enum CodingKeys: String, CodingKey {
        case products = "hits"
        case page
        case pageCount = "page_count"
        case facets
    }

    private enum FacetsKeys: String, CodingKey {
        case brandsTags = "brands_tags"
    }

    private enum FacetKeys: String, CodingKey {
        case items
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        products = try container.decodeIfPresent([Product].self, forKey: .products) ?? []
        page = try? container.decodeIfPresent(Int.self, forKey: .page)
        pageCount = try? container.decodeIfPresent(Int.self, forKey: .pageCount)
        // Facets are optional extras, so a missing or unexpected shape just means no brands.
        let brands = try? container
            .nestedContainer(keyedBy: FacetsKeys.self, forKey: .facets)
            .nestedContainer(keyedBy: FacetKeys.self, forKey: .brandsTags)
            .decodeIfPresent([FacetItem].self, forKey: .items)
        brandFacets = brands ?? []
    }

    /// Whether there's a page after this one. `false` when the response doesn't say.
    var hasMore: Bool {
        guard let page, let pageCount else { return false }
        return page < pageCount
    }

    /// One bucket of a facet: a tag and how many products have it.
    struct FacetItem: Decodable, Sendable {
        /// The tag, such as "lay-s", or `--other--` for the remaining brands.
        let key: String

        /// How many matching products have this tag.
        let count: Int?
    }

    /// One product in the search results.
    struct Product: Decodable, Sendable {
        /// The barcode, which OFF sometimes sends as a number.
        let code: String?

        /// The product name, which may be missing or empty.
        let productName: String?

        /// A comma-separated list of brands.
        let brands: String?

        /// The product's nutrient values.
        let nutriments: Nutriments

        private enum CodingKeys: String, CodingKey {
            case code
            case productName = "product_name"
            case brands
            case nutriments
        }

        /// Creates a product from already-decoded values.
        init(code: String?, productName: String?, brands: String?, nutriments: Nutriments) {
            self.code = code
            self.productName = productName
            self.brands = brands
            self.nutriments = nutriments
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let text = try? container.decodeIfPresent(String.self, forKey: .code) {
                code = text
            } else if let number = try? container.decodeIfPresent(Int64.self, forKey: .code) {
                code = String(number)
            } else {
                code = nil
            }
            productName = try? container.decodeIfPresent(String.self, forKey: .productName)
            // Search-a-licious sends brands as an array; older OFF responses use a comma-separated string.
            if let list = try? container.decodeIfPresent([String].self, forKey: .brands) {
                brands = list.joined(separator: ",")
            } else {
                brands = try? container.decodeIfPresent(String.self, forKey: .brands)
            }
            nutriments = try container.decodeIfPresent(Nutriments.self, forKey: .nutriments) ?? Nutriments(values: [:])
        }
    }

    /// The numeric `*_100g` nutriment fields, keyed by their OFF field name.
    ///
    /// OFF mixes numbers, numeric strings and unit strings in this object, so the
    /// decoder keeps only `_100g` fields that parse as numbers.
    struct Nutriments: Decodable, Sendable {
        /// Values per 100 g, in grams (or kcal / kJ for energy), keyed by field name.
        let values: [String: Double]

        /// Creates nutriments from already-parsed values.
        init(values: [String: Double]) {
            self.values = values
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: AnyCodingKey.self)
            var values: [String: Double] = [:]
            for key in container.allKeys where key.stringValue.hasSuffix("_100g") {
                if let number = try? container.decode(Double.self, forKey: key) {
                    values[key.stringValue] = number
                } else if let text = try? container.decode(String.self, forKey: key), let number = Double(text) {
                    values[key.stringValue] = number
                }
            }
            self.values = values
        }
    }

    /// A coding key for objects whose field names aren't known ahead of time.
    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}
