import SwiftUI
import UIKit

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var cachedImage: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .task(id: url?.absoluteString) {
                        await loadImageIfNeeded()
                    }
            }
        }
    }

    @MainActor
    private func loadImageIfNeeded() async {
        guard cachedImage == nil, !isLoading else { return }
        await loadImage()
    }

    @MainActor
    private func loadImage() async {
        guard let url else { return }

        isLoading = true
        defer { isLoading = false }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let response = URLCache.shared.cachedResponse(for: request),
           let image = UIImage(data: response.data)
        {
            cachedImage = image
            return
        }

        do {
            let (data, response) = try await fetchImageData(
                from: url,
                request: request,
                fallbackPolicy: .reloadIgnoringLocalCacheData
            )

            storeInCacheIfPossible(request: request, response: response, data: data)

            if let image = UIImage(data: data) {
                cachedImage = image
            } else {
                AppLog.warning("Failed to decode image data for \(url.absoluteString)", category: .network)
            }
        } catch {
            AppLog.warning("Failed to load image: \(error.localizedDescription)", category: .network)
        }
    }

    private func fetchImageData(
        from url: URL,
        request: URLRequest,
        fallbackPolicy: URLRequest.CachePolicy
    ) async throws -> (Data, URLResponse) {
        let cachedSession = makeImageSession(cachePolicy: .returnCacheDataElseLoad)

        do {
            let result = try await cachedSession.data(for: request)
            try validateImageResponse(result.0, result.1, url: url)
            return result
        } catch {
            // Retry once with a forced network fetch if cache-first fetch fails.
            var retryRequest = URLRequest(url: url)
            retryRequest.cachePolicy = fallbackPolicy
            let networkSession = makeImageSession(cachePolicy: fallbackPolicy)
            let retryResult = try await networkSession.data(for: retryRequest)
            try validateImageResponse(retryResult.0, retryResult.1, url: url)
            return retryResult
        }
    }

    private func makeImageSession(cachePolicy: URLRequest.CachePolicy) -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = cachePolicy
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }

    private func storeInCacheIfPossible(request: URLRequest, response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse,
              let responseURL = httpResponse.url
        else {
            return
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            headers[String(describing: key)] = String(describing: value)
        }
        headers["Cache-Control"] = "max-age=7776000"

        let modifiedResponse = HTTPURLResponse(
            url: responseURL,
            statusCode: httpResponse.statusCode,
            httpVersion: nil,
            headerFields: headers
        ) ?? response

        let cachedResponse = CachedURLResponse(response: modifiedResponse, data: data)
        URLCache.shared.storeCachedResponse(cachedResponse, for: request)
    }

    private func validateImageResponse(_ data: Data, _ response: URLResponse, url: URL) throws {
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse, userInfo: [
                NSURLErrorFailingURLErrorKey: url
            ])
        }

        if data.isEmpty {
            throw URLError(.zeroByteResource)
        }
    }
}

extension CachedAsyncImage where Content == Image, Placeholder == Color {
    init(url: URL?) {
        self.init(
            url: url,
            content: { $0.resizable() },
            placeholder: { Color.gray.opacity(0.2) }
        )
    }
}
