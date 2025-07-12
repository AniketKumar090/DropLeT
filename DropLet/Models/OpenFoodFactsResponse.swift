import Foundation

struct OpenFoodFactsResponse: Codable {
    let product: OpenFoodFactsProduct?
    let status: Int?
    let status_verbose: String?
}

struct OpenFoodFactsProduct: Codable {
    let product_name: String?
    let quantity: String?
    let image_url: String?
    let categories: String?
    let generic_name: String?
    let _keywords: [String]?

    private enum CodingKeys: String, CodingKey {
        case product_name, quantity, image_url, categories, generic_name
        case _keywords = "_keywords"
    }
}
