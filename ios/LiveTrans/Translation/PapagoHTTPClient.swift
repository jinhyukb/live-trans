import Foundation
import LiveTransCore

struct PapagoHTTPClient: PapagoTranslating {
    private let clientID: String
    private let clientSecret: String
    private let session: URLSession

    static let endpoint = URL(string: "https://openapi.naver.com/v1/papago/n2mt")!

    init(
        clientID: String,
        clientSecret: String,
        session: URLSession = .shared
    ) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.session = session
    }

    func translate(
        _ text: String,
        from source: Language,
        to target: TargetLanguage
    ) async throws -> String {
        guard let sourceCode = source.papagoSourceCode else {
            throw PapagoError.unsupportedSourceLanguage
        }
        guard let targetCode = papagoSourceCode(for: target) else {
            throw PapagoError.unsupportedTargetLanguage
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(clientID, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "source", value: sourceCode),
            URLQueryItem(name: "target", value: targetCode),
            URLQueryItem(name: "text", value: text),
        ]
        request.httpBody = components.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw PapagoError.httpError
        }

        let decoded = try JSONDecoder().decode(PapagoResponse.self, from: data)
        return decoded.message.result.translatedText
    }

    private func papagoSourceCode(for target: TargetLanguage) -> String? {
        switch target {
        case .korean: return "ko"
        }
    }
}

enum PapagoError: Error {
    case unsupportedSourceLanguage
    case unsupportedTargetLanguage
    case httpError
}

private struct PapagoResponse: Decodable {
    struct Message: Decodable {
        struct Result: Decodable {
            let translatedText: String
        }
        let result: Result
    }
    let message: Message
}