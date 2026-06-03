import Foundation

/// 本地数据与远端同步队列之间的状态标记。
/// 当前项目以本地优先为主，后续接入云同步时依赖该字段判断增删改。
enum SyncStatus: String {
    case localOnly
    case pendingCreate
    case pendingUpdate
    case pendingDelete
    case synced
    case failed
}

/// 日记记录中的情绪枚举，用于输入页选择和时间线展示。
enum MoodType: String, CaseIterable {
    case calm
    case happy
    case tired
    case anxious
    case grateful
}

/// 账本流水的收支方向。
enum TransactionType: String, CaseIterable {
    case income
    case expense
}

/// 账本分类。
/// 收入和支出共享同一枚举，展示时通过 `available(for:)` 按类型过滤。
enum TransactionCategory: String, CaseIterable {
    case food
    case transport
    case shopping
    case entertainment
    case home
    case medical
    case salary
    case partTime
    case gift
    case investment
    case other

    static func available(for type: TransactionType) -> [TransactionCategory] {
        switch type {
        case .expense:
            return [.food, .transport, .shopping, .entertainment, .home, .medical, .other]
        case .income:
            return [.salary, .partTime, .gift, .investment, .other]
        }
    }
}

/// 附件所属业务对象类型。
enum AttachmentOwnerType: String {
    case diary
    case transaction
}

/// 附件文件类型。
enum AttachmentType: String {
    case image
    case audio
}

/// 一次记录时保存的位置快照。
/// 使用快照而不是动态查询，保证历史日记和账单不会随当前位置变化而改变。
struct LocationSnapshot: Equatable {
    var name: String?
    var city: String?
    var district: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var isManuallyEdited: Bool
}

/// 一次记录时保存的天气快照。
/// provider 和 fetchedAt 用于区分自动获取、手动填写以及后续排查数据来源。
struct WeatherSnapshot: Equatable {
    var temperature: Double?
    var condition: String?
    var conditionCode: String?
    var humidity: Double?
    var windSpeed: Double?
    var provider: String?
    var fetchedAt: Date?
}

/// 日记领域模型。
/// 通过 `deletedAt` 做软删除，避免本地删除在未来同步前丢失语义。
struct DiaryEntry: Equatable {
    var localId: UUID
    var remoteId: String?
    var content: String
    var mood: MoodType
    var entryDate: Date
    var location: LocationSnapshot?
    var weather: WeatherSnapshot?
    var isFavorite: Bool
    var isDraft: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatus: SyncStatus
}

/// 账本流水领域模型。
/// 与日记共享位置和天气快照，方便首页按日期聚合当天上下文。
struct LedgerTransaction: Equatable {
    var localId: UUID
    var remoteId: String?
    var amount: Decimal
    var type: TransactionType
    var category: TransactionCategory
    var accountId: UUID?
    var note: String?
    var detailText: String?
    var transactionDate: Date
    var location: LocationSnapshot?
    var weather: WeatherSnapshot?
    var isDraft: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatus: SyncStatus
}

/// 附件领域模型。
/// 附件用 ownerId + ownerType 关联到日记或账单，避免为不同业务表重复建附件模型。
struct Attachment: Equatable {
    var localId: UUID
    var remoteId: String?
    var ownerId: UUID
    var ownerType: AttachmentOwnerType
    var type: AttachmentType
    var localFilePath: String
    var remoteURL: String?
    var fileName: String?
    var mimeType: String?
    var fileSize: Int64?
    var duration: TimeInterval?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatus: SyncStatus
}

/// 日记标签领域模型。
struct Tag: Equatable {
    var localId: UUID
    var remoteId: String?
    var name: String
    var colorHex: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatus: SyncStatus
}

/// 账本账户领域模型。
struct Account: Equatable {
    var localId: UUID
    var remoteId: String?
    var name: String
    var isDefault: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var syncStatus: SyncStatus
}

/// 首页按天聚合后的展示模型。
/// 聚合结果优先使用当天最新日记的位置和天气，其次使用最新账单的上下文。
struct DailyOverview: Equatable {
    var date: Date
    var location: LocationSnapshot?
    var weather: WeatherSnapshot?
    var latestDiary: DiaryEntry?
    var diaries: [DiaryEntry]
    var todayIncome: Decimal
    var todayExpense: Decimal
    var todayBalance: Decimal
    var latestTransaction: LedgerTransaction?
}

/// 月账本分类占比。
struct CategorySummary: Equatable {
    var category: TransactionCategory
    var amount: Decimal
    var percentage: Double
}

/// 月账本每日累计余额点。
struct DailyBalancePoint: Equatable {
    var date: Date
    var balance: Decimal
}

/// 月账本汇总结果。
struct MonthlyLedgerSummary: Equatable {
    var month: Date
    var income: Decimal
    var expense: Decimal
    var balance: Decimal
    var categorySummaries: [CategorySummary]
    var dailyBalancePoints: [DailyBalancePoint]
}
