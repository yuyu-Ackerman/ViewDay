import CoreData
import Foundation

/// Core Data 与领域模型之间的值映射工具。
/// 多个实体共享位置、天气和同步字段，因此集中在这里保持字段名一致。
enum CoreDataValueMapper {
    // Core Data 在不同模型版本或桥接路径下可能返回 NSNumber，这些方法统一做容错转换。
    static func double(_ object: NSManagedObject, key: String) -> Double? {
        if let value = object.value(forKey: key) as? Double {
            return value
        }

        return (object.value(forKey: key) as? NSNumber)?.doubleValue
    }

    static func int(_ object: NSManagedObject, key: String) -> Int? {
        if let value = object.value(forKey: key) as? Int {
            return value
        }

        return (object.value(forKey: key) as? NSNumber)?.intValue
    }

    static func int64(_ object: NSManagedObject, key: String) -> Int64? {
        if let value = object.value(forKey: key) as? Int64 {
            return value
        }

        return (object.value(forKey: key) as? NSNumber)?.int64Value
    }

    /// 写入所有支持未来同步所需的公共字段。
    static func applySyncFields(to object: NSManagedObject, remoteId: String?, createdAt: Date, updatedAt: Date, deletedAt: Date?, syncStatus: SyncStatus) {
        object.setValue(remoteId, forKey: "remoteId")
        object.setValue(createdAt, forKey: "createdAt")
        object.setValue(updatedAt, forKey: "updatedAt")
        object.setValue(deletedAt, forKey: "deletedAt")
        object.setValue(syncStatus.rawValue, forKey: "syncStatus")
    }

    /// 从实体字段还原位置快照。
    /// 所有位置字段都为空时返回 nil，避免页面误判为手动空位置。
    static func location(from object: NSManagedObject) -> LocationSnapshot? {
        let name = object.value(forKey: "locationName") as? String
        let city = object.value(forKey: "city") as? String
        let district = object.value(forKey: "district") as? String
        let address = object.value(forKey: "address") as? String
        let latitude = double(object, key: "latitude")
        let longitude = double(object, key: "longitude")
        let isManuallyEdited = object.value(forKey: "isLocationManuallyEdited") as? Bool ?? false

        if name == nil, city == nil, district == nil, address == nil, latitude == nil, longitude == nil {
            return nil
        }

        return LocationSnapshot(
            name: name,
            city: city,
            district: district,
            address: address,
            latitude: latitude,
            longitude: longitude,
            isManuallyEdited: isManuallyEdited
        )
    }

    /// 将位置快照展开写入实体字段。
    static func apply(_ location: LocationSnapshot?, to object: NSManagedObject) {
        object.setValue(location?.name, forKey: "locationName")
        object.setValue(location?.city, forKey: "city")
        object.setValue(location?.district, forKey: "district")
        object.setValue(location?.address, forKey: "address")
        object.setValue(location?.latitude, forKey: "latitude")
        object.setValue(location?.longitude, forKey: "longitude")
        object.setValue(location?.isManuallyEdited ?? false, forKey: "isLocationManuallyEdited")
    }

    /// 从实体字段还原天气快照。
    /// 所有天气字段都为空时返回 nil，便于首页按已有记录做 fallback。
    static func weather(from object: NSManagedObject) -> WeatherSnapshot? {
        let temperature = double(object, key: "temperature")
        let condition = object.value(forKey: "condition") as? String
        let conditionCode = object.value(forKey: "conditionCode") as? String
        let humidity = double(object, key: "humidity")
        let windSpeed = double(object, key: "windSpeed")
        let provider = object.value(forKey: "weatherProvider") as? String
        let fetchedAt = object.value(forKey: "weatherFetchedAt") as? Date

        if temperature == nil, condition == nil, conditionCode == nil, humidity == nil, windSpeed == nil, provider == nil, fetchedAt == nil {
            return nil
        }

        return WeatherSnapshot(
            temperature: temperature,
            condition: condition,
            conditionCode: conditionCode,
            humidity: humidity,
            windSpeed: windSpeed,
            provider: provider,
            fetchedAt: fetchedAt
        )
    }

    /// 将天气快照展开写入实体字段。
    static func apply(_ weather: WeatherSnapshot?, to object: NSManagedObject) {
        object.setValue(weather?.temperature, forKey: "temperature")
        object.setValue(weather?.condition, forKey: "condition")
        object.setValue(weather?.conditionCode, forKey: "conditionCode")
        object.setValue(weather?.humidity, forKey: "humidity")
        object.setValue(weather?.windSpeed, forKey: "windSpeed")
        object.setValue(weather?.provider, forKey: "weatherProvider")
        object.setValue(weather?.fetchedAt, forKey: "weatherFetchedAt")
    }
}
