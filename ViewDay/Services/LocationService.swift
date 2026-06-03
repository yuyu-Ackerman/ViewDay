import CoreLocation
import Foundation

/// 定位流程中的业务错误。
/// 页面层会根据权限错误展示设置入口，其他失败则回退到手动地点。
enum LocationServiceError: Error, Equatable {
    /// 用户拒绝或系统限制定位权限。
    case permissionDenied
    /// 授权状态、定位结果或反地理编码不可用。
    case locationUnavailable
}

/// 定位服务协议。
/// 页面层通过协议依赖定位能力，方便在测试或预览中注入固定位置。
protocol LocationServiceProtocol {
    /// 请求一次当前位置，并返回可保存到记录中的位置快照。
    ///
    /// - Parameter completion: 定位完成回调，成功时返回包含坐标和可读名称的位置快照。
    func requestCurrentLocation(completion: @escaping (Result<LocationSnapshot, Error>) -> Void)
}

/// 基于 CoreLocation 的一次性定位服务。
/// 服务会先使用系统反地理编码，名称不可读时再请求 BigDataCloud 做兜底。
final class LocationService: NSObject, LocationServiceProtocol {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var completion: ((Result<LocationSnapshot, Error>) -> Void)?
    private var remainingLocationRetries = 0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation(completion: @escaping (Result<LocationSnapshot, Error>) -> Void) {
        self.completion = completion
        remainingLocationRetries = 2

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            complete(.failure(LocationServiceError.permissionDenied))
        @unknown default:
            complete(.failure(LocationServiceError.locationUnavailable))
        }
    }

    private func resolve(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_Hans_CN")) { [weak self] placemarks, _ in
            guard let self else { return }
            let snapshot = self.snapshot(from: placemarks?.first, location: location)

            guard snapshot.hasReadableName else {
                // 某些区域系统反地理编码只返回坐标文本，使用公开接口补足城市或区域名称。
                Task { [weak self] in
                    let fallbackSnapshot = (try? await self?.fetchBigDataCloudLocation(for: location)) ?? snapshot
                    self?.complete(.success(fallbackSnapshot))
                }
                return
            }

            self.complete(.success(snapshot))
        }
    }

    private func snapshot(from placemark: CLPlacemark?, location: CLLocation) -> LocationSnapshot {
        let coordinateText = coordinateText(for: location)
        let streetAddress = [placemark?.thoroughfare, placemark?.subThoroughfare]
            .compactMap { $0 }
            .joined()
        let city = placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea
        let district = placemark?.subLocality
        let placemarkName = specificPlacemarkName(placemark?.name, city: city, district: district)
        // 名称优先级从具体兴趣点到行政区域逐级回退，避免首页只显示宽泛城市名。
        let placeName = [
            placemark?.areasOfInterest?.first,
            streetAddress.isEmpty ? nil : streetAddress,
            placemarkName,
            district,
            city
        ]
        .compactMap { $0 }
        .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return LocationSnapshot(
            name: placeName ?? coordinateText,
            city: city,
            district: district,
            address: [
                placemark?.country,
                placemark?.administrativeArea,
                city,
                placemark?.subLocality,
                streetAddress.isEmpty ? nil : streetAddress,
                placemark?.areasOfInterest?.first
            ]
            .compactMap { $0 }
            .removingDuplicates()
            .joined(separator: " "),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            isManuallyEdited: false
        )
    }

    private func fetchBigDataCloudLocation(for location: CLLocation) async throws -> LocationSnapshot {
        var components = URLComponents(string: "https://api.bigdatacloud.net/data/reverse-geocode-client")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: "\(location.coordinate.latitude)"),
            URLQueryItem(name: "longitude", value: "\(location.coordinate.longitude)"),
            URLQueryItem(name: "localityLanguage", value: "zh")
        ]

        guard let url = components?.url else {
            throw LocationServiceError.locationUnavailable
        }

        let response: BigDataCloudReverseGeocodeResponse = try await locationWithTimeout(seconds: 6) {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw LocationServiceError.locationUnavailable
            }
            return try JSONDecoder().decode(BigDataCloudReverseGeocodeResponse.self, from: data)
        }

        let city = response.city ?? response.principalSubdivision
        let district = normalizedDistrict(response.locality, city: city)
        let name = [
            normalizedSpecificName(response.locality, city: city, district: district),
            response.city,
            response.principalSubdivision,
            response.countryName
        ]
        .compactMap { $0 }
        .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return LocationSnapshot(
            name: name ?? coordinateText(for: location),
            city: city,
            district: district,
            address: [
                response.countryName,
                response.principalSubdivision,
                response.city,
                response.locality
            ]
            .compactMap { $0 }
            .removingDuplicates()
            .joined(separator: " "),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            isManuallyEdited: false
        )
    }

    private func coordinateText(for location: CLLocation) -> String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    private func specificPlacemarkName(_ name: String?, city: String?, district: String?) -> String? {
        normalizedSpecificName(name, city: city, district: district)
    }

    private func normalizedSpecificName(_ name: String?, city: String?, district: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        if name == city || name == district {
            return nil
        }

        return name
    }

    private func normalizedDistrict(_ district: String?, city: String?) -> String? {
        guard let district = district?.trimmingCharacters(in: .whitespacesAndNewlines), !district.isEmpty else {
            return nil
        }

        return district == city ? nil : district
    }

    private func complete(_ result: Result<LocationSnapshot, Error>) {
        completion?(result)
        completion = nil
    }
}

private struct BigDataCloudReverseGeocodeResponse: Decodable {
    var locality: String?
    var city: String?
    var principalSubdivision: String?
    var countryName: String?
}

/// 给反地理编码兜底请求加超时，避免定位成功后回调被网络请求长期占用。
private func locationWithTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw LocationServiceError.locationUnavailable
        }

        guard let result = try await group.next() else {
            throw LocationServiceError.locationUnavailable
        }
        group.cancelAll()
        return result
    }
}

private extension LocationSnapshot {
    var hasReadableName: Bool {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return false
        }

        // 只有坐标字符串时仍允许 city/district 补充上下文，否则视为不可读名称。
        return !name.contains(",") || city != nil || district != nil
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            complete(.failure(LocationServiceError.permissionDenied))
        case .notDetermined:
            break
        @unknown default:
            complete(.failure(LocationServiceError.locationUnavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            complete(.failure(LocationServiceError.locationUnavailable))
            return
        }

        resolve(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .locationUnknown, remainingLocationRetries > 0 {
            remainingLocationRetries -= 1
            manager.requestLocation()
            return
        }

        complete(.failure(error))
    }
}
