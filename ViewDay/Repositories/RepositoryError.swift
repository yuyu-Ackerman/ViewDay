import Foundation

/// 仓储层错误。
/// 当前主要用于标记 Core Data 实体缺少必要字段或字段值无法映射到领域模型。
enum RepositoryError: Error {
    /// Core Data 中的实体数据不满足领域模型的必填字段要求。
    case invalidStoredObject(entityName: String)
}
