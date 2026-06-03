import Foundation

struct HomeLocationDisplayText: Equatable {
    let title: String
    let subtitle: String
}

enum HomeLocationDisplayFormatter {
    static func text(from location: LocationSnapshot?) -> HomeLocationDisplayText {
        HomeLocationDisplayText(
            title: title(from: location),
            subtitle: subtitle(from: location)
        )
    }

    static func title(from location: LocationSnapshot?) -> String {
        guard let location else { return "当前位置" }

        let city = normalizedCity(from: [location.city, extractedCity(from: location.address)])
        let district = normalizedDistrict(from: [location.district, extractedDistrict(from: location.address)])
        let administrativeNames = Set([city, district].compactMap { $0 })
        let explicitName = clean(location.name)

        if let explicitName, !isCoordinate(explicitName), !administrativeNames.contains(explicitName) {
            return shortenedPlaceName(explicitName)
        }

        if let specificAddressName = specificName(from: location.address, administrativeNames: administrativeNames) {
            return shortenedPlaceName(specificAddressName)
        }

        if let explicitName, !isCoordinate(explicitName) {
            return shortenedPlaceName(explicitName)
        }

        return district ?? city ?? "当前位置"
    }

    static func subtitle(from location: LocationSnapshot?) -> String {
        guard let location else { return "城市 · 区域" }

        let extractedCity = extractedCity(from: location.address)
        let extractedDistrict = extractedDistrict(from: location.address)
        let district = normalizedDistrict(from: [location.district, extractedDistrict])
        let city = normalizedCity(from: [location.city, extractedCity], excluding: district)

        if let city, let district {
            return "\(city) · \(district)"
        }

        return city ?? district ?? "当前位置"
    }

    private static func specificName(from address: String?, administrativeNames: Set<String>) -> String? {
        guard var source = clean(address), !source.isEmpty else { return nil }

        source = source.replacingOccurrences(of: "中国", with: "")
        source = source.replacingOccurrences(
            of: #"[\u{4e00}-\u{9fa5}]{2,12}(省|自治区|特别行政区)"#,
            with: "",
            options: .regularExpression
        )
        administrativeNames.forEach { source = source.replacingOccurrences(of: $0, with: "") }

        return source
            .components(separatedBy: CharacterSet(charactersIn: " ,，·/|-"))
            .map(clean)
            .compactMap { $0 }
            .filter { !administrativeNames.contains($0) }
            .filter { !isAdministrativeArea($0) }
            .last
            .map(strippingContextSuffix)
    }

    private static func normalizedCity(from candidates: [String?], excluding district: String? = nil) -> String? {
        candidates
            .compactMap(clean)
            .first { candidate in
                candidate != district && !candidate.hasSuffix("区") && !candidate.hasSuffix("县") && !candidate.hasSuffix("旗")
            }
    }

    private static func normalizedDistrict(from candidates: [String?]) -> String? {
        candidates
            .compactMap(clean)
            .first { candidate in
                candidate.hasSuffix("区") || candidate.hasSuffix("县") || candidate.hasSuffix("旗")
            }
    }

    private static func extractedCity(from source: String?) -> String? {
        firstMatch(in: source, pattern: #"[\u{4e00}-\u{9fa5}]{2,12}市"#)
    }

    private static func extractedDistrict(from source: String?) -> String? {
        firstMatch(in: source, pattern: #"[\u{4e00}-\u{9fa5}]{1,12}[区县旗]"#)
    }

    private static func firstMatch(in source: String?, pattern: String) -> String? {
        guard let source else { return nil }
        guard let range = source.range(of: pattern, options: .regularExpression) else { return nil }
        return clean(String(source[range]))
    }

    private static func shortenedPlaceName(_ name: String) -> String {
        let candidate = strippingContextSuffix(name)
        return candidate.count > 14 ? "\(candidate.prefix(14))..." : candidate
    }

    private static func strippingContextSuffix(_ name: String) -> String {
        var candidate = name
        ["一带", "附近", "周边"].forEach { suffix in
            if candidate.hasSuffix(suffix) {
                candidate.removeLast(suffix.count)
            }
        }
        return candidate.isEmpty ? name : candidate
    }

    private static func isCoordinate(_ text: String) -> Bool {
        text.contains(",") && text.range(of: #"-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?"#, options: .regularExpression) != nil
    }

    private static func isAdministrativeArea(_ text: String) -> Bool {
        text.hasSuffix("省") || text.hasSuffix("市") || text.hasSuffix("区") || text.hasSuffix("县") || text.hasSuffix("旗")
    }

    private static func clean(_ text: String?) -> String? {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
