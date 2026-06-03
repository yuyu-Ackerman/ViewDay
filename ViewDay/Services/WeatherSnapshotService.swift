import CoreLocation
import Foundation

#if canImport(WeatherKit)
import WeatherKit
#endif

/// 天气获取过程中的业务错误。
/// 页面层会把这些错误转换为可手动填写天气的提示。
enum WeatherSnapshotServiceError: Error {
    /// 当前系统或构建配置无法使用 WeatherKit。
    case weatherKitUnavailable
    /// 位置快照没有经纬度，无法调用天气接口。
    case coordinatesUnavailable
    /// 第三方服务响应缺失、HTTP 状态异常或 JSON 无法映射。
    case invalidResponse
}

extension WeatherSnapshotServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .weatherKitUnavailable:
            return "当前系统环境无法使用 WeatherKit。"
        case .coordinatesUnavailable:
            return "当前位置没有坐标，无法自动获取天气。"
        case .invalidResponse:
            return "天气服务返回的数据无法识别。"
        }
    }
}

/// 天气快照获取服务协议。
/// 页面层只依赖该协议，便于测试或替换不同天气数据源。
protocol WeatherSnapshotServiceProtocol {
    /// 根据位置坐标获取当前天气快照。
    ///
    /// - Parameter location: 需要包含经纬度的位置快照。
    /// - Returns: 可直接保存到日记或账单的天气快照。
    func fetchWeather(for location: LocationSnapshot) async throws -> WeatherSnapshot
}

/// 多数据源天气服务。
///
/// 获取顺序为 Open-Meteo、wttr.in、WeatherKit。前两个无需额外配置，WeatherKit 仅在
/// Info.plist 显式启用且系统支持时作为最后兜底。
final class WeatherSnapshotService: WeatherSnapshotServiceProtocol {
    func fetchWeather(for location: LocationSnapshot) async throws -> WeatherSnapshot {
        guard let latitude = location.latitude, let longitude = location.longitude else {
            throw WeatherSnapshotServiceError.coordinatesUnavailable
        }

        // 优先使用无需鉴权的公开服务，避免 WeatherKit 权限或配置问题影响记录流程。
        do {
            return try await withTimeout(seconds: 6) {
                try await self.fetchOpenMeteo(latitude: latitude, longitude: longitude)
            }
        } catch {
            do {
                return try await withTimeout(seconds: 6) {
                    try await self.fetchWttr(latitude: latitude, longitude: longitude)
                }
            } catch {
                if Bundle.main.object(forInfoDictionaryKey: "ViewDayWeatherKitEnabled") as? Bool == true, #available(iOS 16.0, *) {
                    let weather = try await withTimeout(seconds: 5) {
                        try await self.fetchWeatherKit(latitude: latitude, longitude: longitude)
                    }
                    return weather
                }

                throw error
            }
        }
    }

    private func fetchOpenMeteo(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: "\(latitude)"),
            URLQueryItem(name: "longitude", value: "\(longitude)"),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw WeatherSnapshotServiceError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherSnapshotServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        guard let current = decoded.current else {
            throw WeatherSnapshotServiceError.invalidResponse
        }

        let weatherCode = current.weatherCode
        return WeatherSnapshot(
            temperature: current.temperature,
            condition: weatherCode.map(Self.conditionText(for:)),
            conditionCode: weatherCode.map(String.init),
            humidity: current.humidity.map { $0 / 100 },
            windSpeed: current.windSpeed,
            provider: "Open-Meteo",
            fetchedAt: Date()
        )
    }

    private func fetchWttr(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://wttr.in/\(latitude),\(longitude)")
        components?.queryItems = [
            URLQueryItem(name: "format", value: "j1"),
            URLQueryItem(name: "lang", value: "zh")
        ]

        guard let url = components?.url else {
            throw WeatherSnapshotServiceError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw WeatherSnapshotServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(WttrResponse.self, from: data)
        guard let current = decoded.currentCondition.first else {
            throw WeatherSnapshotServiceError.invalidResponse
        }

        let condition = current.localizedCondition ?? current.weatherDescription ?? current.weatherCode.map(Self.conditionText(for:))
        return WeatherSnapshot(
            temperature: current.temperature,
            condition: condition,
            conditionCode: current.weatherCode.map(String.init),
            humidity: current.humidity.map { $0 / 100 },
            windSpeed: current.windSpeed,
            provider: "wttr.in",
            fetchedAt: Date()
        )
    }

    private static func conditionText(for code: Int) -> String {
        // Open-Meteo 和 wttr.in 都会返回 WMO 天气码，这里统一转成本地化短文案。
        switch code {
        case 0:
            return "晴"
        case 1, 2:
            return "少云"
        case 3:
            return "阴"
        case 45, 48:
            return "雾"
        case 51, 53, 55, 56, 57:
            return "毛毛雨"
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return "雨"
        case 71, 73, 75, 77, 85, 86:
            return "雪"
        case 95, 96, 99:
            return "雷雨"
        default:
            return "天气已获取"
        }
    }

    #if canImport(WeatherKit)
    @available(iOS 16.0, *)
    private func fetchWeatherKit(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        let currentWeather = try await WeatherService.shared.weather(for: CLLocation(latitude: latitude, longitude: longitude)).currentWeather
        return WeatherSnapshot(
            temperature: currentWeather.temperature.value,
            condition: currentWeather.condition.description,
            conditionCode: String(describing: currentWeather.condition),
            humidity: currentWeather.humidity,
            windSpeed: currentWeather.wind.speed.value,
            provider: "WeatherKit",
            fetchedAt: Date()
        )
    }
    #else
    private func fetchWeatherKit(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        throw WeatherSnapshotServiceError.weatherKitUnavailable
    }
    #endif
}

/// 给第三方天气请求加超时，避免首页刷新或记录页元信息长时间停在加载态。
private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw WeatherSnapshotServiceError.invalidResponse
        }

        guard let result = try await group.next() else {
            throw WeatherSnapshotServiceError.invalidResponse
        }
        group.cancelAll()
        return result
    }
}

private struct OpenMeteoResponse: Decodable {
    var current: CurrentWeather?

    struct CurrentWeather: Decodable {
        var temperature: Double?
        var humidity: Double?
        var windSpeed: Double?
        var weatherCode: Int?

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case humidity = "relative_humidity_2m"
            case windSpeed = "wind_speed_10m"
            case weatherCode = "weather_code"
        }
    }
}

private struct WttrResponse: Decodable {
    var currentCondition: [CurrentCondition]

    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
    }

    struct CurrentCondition: Decodable {
        var temperature: Double?
        var humidity: Double?
        var windSpeed: Double?
        var weatherCode: Int?
        var weatherDescription: String?
        var localizedCondition: String?

        enum CodingKeys: String, CodingKey {
            case temperature = "temp_C"
            case humidity
            case windSpeed = "windspeedKmph"
            case weatherCode
            case weatherDescription = "weatherDesc"
            case localizedCondition = "lang_zh"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            temperature = Double(try container.decodeIfPresent(String.self, forKey: .temperature) ?? "")
            humidity = Double(try container.decodeIfPresent(String.self, forKey: .humidity) ?? "")
            windSpeed = Double(try container.decodeIfPresent(String.self, forKey: .windSpeed) ?? "")
            weatherCode = Int(try container.decodeIfPresent(String.self, forKey: .weatherCode) ?? "")
            weatherDescription = try container.decodeIfPresent([WttrTextValue].self, forKey: .weatherDescription)?.first?.value
            localizedCondition = try container.decodeIfPresent([WttrTextValue].self, forKey: .localizedCondition)?.first?.value
        }
    }

    struct WttrTextValue: Decodable {
        var value: String
    }
}
