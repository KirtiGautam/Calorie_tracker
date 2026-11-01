/// The Open Food Facts `api/v2/product/{code}` response, limited to the requested fields.
nonisolated struct OFFProductResponse: Decodable, Sendable {
    /// 1 when the product was found, 0 when it wasn't or the code is invalid.
    let status: Int?

    /// The product, present when `status` is 1.
    let product: OFFSearchResponse.Product?
}
