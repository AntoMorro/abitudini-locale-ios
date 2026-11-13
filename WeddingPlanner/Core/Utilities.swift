import Foundation

enum Money {
    static func digits(_ currency: String) -> Int { currency == "JPY" ? 0 : 2 }
    static func parse(_ text: String, currency: String) throws -> Int64 {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        let d = digits(currency)
        guard parts.count <= 2, !normalized.isEmpty, parts.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }), !(parts.first?.isEmpty ?? true), (parts.count == 1 || parts[1].count <= d), let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value >= 0 else { throw WeddingError.invalid("Importo non valido. Usa cifre e una virgola, senza separatori delle migliaia.") }
        let scaled = value * (d == 0 ? 1 : 100)
        guard scaled <= 1_000_000_000_000 else { throw WeddingError.invalid("Importo troppo grande.") }
        return NSDecimalNumber(decimal: scaled).int64Value
    }
    static func input(_ amount: Int64, currency: String) -> String {
        if digits(currency) == 0 { return String(amount) }
        return "\(amount / 100),\(String(format: "%02lld", abs(amount % 100)))"
    }
    static func format(_ amount: Int64, currency: String) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = currency; f.locale = Locale(identifier: "it_IT")
        return f.string(from: NSDecimalNumber(decimal: Decimal(amount) / (digits(currency) == 0 ? 1 : 100))) ?? "\(amount) \(currency)"
    }
}
enum WeddingExport {
    static func csv(_ rows: [[String]]) -> String {
        rows.map { $0.map { field in
            let risky = field.drop(while: { $0.isWhitespace }).first.map { "=+-@".contains($0) } ?? false
            let safe = risky ? "'" + field : field
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }
    static func guests(_ db: WeddingArchive) -> String {
        csv([["Nome", "Nucleo / gruppo", "RSVP", "Accompagnatori", "Posti richiesti", "Alimentazione", "Allergie", "Tavolo", "Note"]] + db.guests.map { g in [g.name,g.group,g.rsvp.rawValue,String(g.companions),String(g.seats),g.diet,g.allergies,db.tables.first { $0.id == g.tableID }?.name ?? "",g.notes] })
    }
    static func schedule(_ db: WeddingArchive) -> String {
        let formatter = ISO8601DateFormatter()
        return csv([["Titolo", "Inizio ISO8601", "Durata minuti", "Luogo", "Responsabile", "Fornitore", "Note"]] + db.schedule.sorted { $0.start < $1.start }.map { s in [s.title,formatter.string(from:s.start),String(s.minutes),s.location,s.owner,db.vendors.first { $0.id == s.vendorID }?.name ?? "",s.notes] })
    }
}
