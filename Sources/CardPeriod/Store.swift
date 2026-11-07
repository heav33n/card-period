#if canImport(SwiftUI)
import SwiftUI

@MainActor final class CardStore: ObservableObject {
    @Published var cards: [SpendingCard] = [] { didSet { save() } }
    @Published var error: String?
    private let url: URL
    init() {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        url = directory.appendingPathComponent("cards.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do { cards = try JSONDecoder().decode([SpendingCard].self, from: Data(contentsOf: url)) }
        catch { self.error = "Your saved cards could not be loaded. They have not been overwritten." }
    }
    private func save() {
        // Never overwrite a file that could not be decoded.
        guard error == nil else { return }
        do { try JSONEncoder().encode(cards).write(to: url, options: .atomic) }
        catch { self.error = "Changes could not be saved on this device." }
    }
    func put(_ card: SpendingCard) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) { cards[index] = card }
        else { cards.append(card) }
    }
    func remove(_ card: SpendingCard) { cards.removeAll { $0.id == card.id } }
}

// The provider returns one reference-rate table per base currency, updated daily.
struct ExchangeRateTable: Codable {
    let result: String
    let base_code: String
    let time_last_update_unix: TimeInterval
    let time_next_update_unix: TimeInterval
    let rates: [String: Decimal]
    var fetchedAt: Date?
}

@MainActor final class ExchangeRateStore: ObservableObject {
    @Published var table: ExchangeRateTable?
    @Published var isLoading = false
    @Published var unavailable = false

    func load(base: String, target: String) async {
        table = nil
        unavailable = false
        guard base != target else { return }
        let key = "exchangeRates." + base
        let cached = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(ExchangeRateTable.self, from: $0) }
        if let cached, cached.base_code == base, cached.rates[target] != nil { table = cached }
        if let cached, cached.base_code == base,
           let fetchedAt = cached.fetchedAt,
           Date().timeIntervalSince(fetchedAt) < 3600 || Date().timeIntervalSince1970 < cached.time_next_update_unix {
            unavailable = cached.rates[target] == nil
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            guard base.count == 3, base.allSatisfy({ $0.isASCII && $0.isUppercase }),
                  let url = URL(string: "https://open.er-api.com/v6/latest/" + base) else { throw URLError(.badURL) }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            var result = try JSONDecoder().decode(ExchangeRateTable.self, from: data)
            guard result.result == "success", result.base_code == base else { throw URLError(.cannotParseResponse) }
            result.fetchedAt = Date()
            if let encoded = try? JSONEncoder().encode(result) { UserDefaults.standard.set(encoded, forKey: key) }
            guard !Task.isCancelled else { return }
            table = result.rates[target] == nil ? nil : result
            unavailable = result.rates[target] == nil
        } catch {
            guard !Task.isCancelled else { return }
            unavailable = table == nil
        }
    }
}

#endif
