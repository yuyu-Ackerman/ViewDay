import Foundation

/// 首页地点展示文案。
/// title 面向主卡片的大字号位置名，subtitle 用于补充城市和区县层级。
struct HomeLocationDisplayText: Equatable {
    let title: String
    let subtitle: String
}

/// 首页地点文案格式化器。
///
/// CoreLocation 和第三方反地理编码返回的字段稳定性不同：有时 name 是坐标，有时 address
/// 包含完整行政区，有时 city/district 缺失。该工具把这些来源规整成“具体地点 + 行政区”
/// 两行文案，避免首页只显示坐标、省市名或过长地址。
enum HomeLocationDisplayFormatter {
    /// 生成首页可直接展示的地点文案。
    ///
    /// - Parameter location: 记录或实时定位得到的位置快照；为空时返回占位文案。
    /// - Returns: 已按首页展示规则拆分好的标题和副标题。
    static func text(from location: LocationSnapshot?) -> HomeLocationDisplayText {
        HomeLocationDisplayText(
            title: title(from: location),
            subtitle: subtitle(from: location)
        )
    }

    /// 生成主标题，优先展示具体 POI 或手动地点，必要时回退到区县、城市。
    ///
    /// 标题需要比行政区更具体，因此会跳过坐标文本和与 city/district 相同的名称。
    /// 当 name 不可用时，会尝试从完整地址中剥离国家、省份、市区后取最后一个具体片段。
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

    /// 生成副标题，展示更稳定的城市和区县上下文。
    ///
    /// city/district 字段缺失时会从 address 提取，避免第三方接口只返回 address 时副标题为空。
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

    /// 从完整地址里提取最具体的地点名称。
    ///
    /// 反地理编码地址常包含“国家/省份/城市/区县/道路/兴趣点”的长串文本。
    /// 首页标题只需要最后的具体地点，因此这里先移除行政区上下文，再按常见分隔符取末尾片段。
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

    /// 选择城市候选值。
    /// 如果候选值其实是区县，会留给 district 处理，避免标题下方出现“浦东新区 · 浦东新区”。
    private static func normalizedCity(from candidates: [String?], excluding district: String? = nil) -> String? {
        candidates
            .compactMap(clean)
            .first { candidate in
                candidate != district && !candidate.hasSuffix("区") && !candidate.hasSuffix("县") && !candidate.hasSuffix("旗")
            }
    }

    /// 选择区县候选值。
    /// 当前主要覆盖中文地址中的区、县、旗，后续如果支持海外地址可在这里扩展。
    private static func normalizedDistrict(from candidates: [String?]) -> String? {
        candidates
            .compactMap(clean)
            .first { candidate in
                candidate.hasSuffix("区") || candidate.hasSuffix("县") || candidate.hasSuffix("旗")
            }
    }

    /// 从完整地址中提取城市名。
    private static func extractedCity(from source: String?) -> String? {
        firstMatch(in: source, pattern: #"[\u{4e00}-\u{9fa5}]{2,12}市"#)
    }

    /// 从完整地址中提取区县旗名称。
    private static func extractedDistrict(from source: String?) -> String? {
        firstMatch(in: source, pattern: #"[\u{4e00}-\u{9fa5}]{1,12}[区县旗]"#)
    }

    /// 返回正则命中的首个片段，并统一做空白清理。
    private static func firstMatch(in source: String?, pattern: String) -> String? {
        guard let source else { return nil }
        guard let range = source.range(of: pattern, options: .regularExpression) else { return nil }
        return clean(String(source[range]))
    }

    /// 限制首页大标题长度。
    /// 这里保留完整字段在模型中，只裁剪展示文案，避免影响详情页或未来同步数据。
    private static func shortenedPlaceName(_ name: String) -> String {
        let candidate = strippingContextSuffix(name)
        return candidate.count > 14 ? "\(candidate.prefix(14))..." : candidate
    }

    /// 去掉中文反地理编码常见的模糊后缀，让标题更像地点名而不是范围描述。
    private static func strippingContextSuffix(_ name: String) -> String {
        var candidate = name
        ["一带", "附近", "周边"].forEach { suffix in
            if candidate.hasSuffix(suffix) {
                candidate.removeLast(suffix.count)
            }
        }
        return candidate.isEmpty ? name : candidate
    }

    /// 判断文本是否只是经纬度坐标。
    /// 坐标可以保留在 LocationSnapshot 中，但不适合作为首页的人类可读标题。
    private static func isCoordinate(_ text: String) -> Bool {
        text.contains(",") && text.range(of: #"-?\d+(\.\d+)?,\s*-?\d+(\.\d+)?"#, options: .regularExpression) != nil
    }

    /// 判断文本是否是纯行政区域名称。
    /// 纯行政区会放到副标题中，主标题尽量留给更具体的位置。
    private static func isAdministrativeArea(_ text: String) -> Bool {
        text.hasSuffix("省") || text.hasSuffix("市") || text.hasSuffix("区") || text.hasSuffix("县") || text.hasSuffix("旗")
    }

    /// 统一清理可选字符串。
    /// 所有入口都走这里，保证空白字符串不会被当成有效地点候选。
    private static func clean(_ text: String?) -> String? {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
