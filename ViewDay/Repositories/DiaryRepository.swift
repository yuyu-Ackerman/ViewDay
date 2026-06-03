import CoreData
import Foundation

/// 日记仓储协议。
/// 页面层通过协议读写日记，便于测试时替换为内存实现。
protocol DiaryRepositoryProtocol {
    /// 保存或更新日记。
    ///
    /// - Parameter diary: 待保存的日记领域模型。
    /// - Returns: 从 Core Data 重新映射后的日记模型。
    @discardableResult
    func save(_ diary: DiaryEntry) throws -> DiaryEntry

    /// 按本地 ID 获取单篇日记。
    func fetchDiary(id: UUID) throws -> DiaryEntry?

    /// 获取指定日期内的所有未删除日记，包含草稿。
    func fetchDiaries(on date: Date, calendar: Calendar) throws -> [DiaryEntry]

    /// 获取指定日期内最新一篇正式日记。
    func fetchLatestDiary(on date: Date, calendar: Calendar) throws -> DiaryEntry?

    /// 获取最近日记，可按正文、地点和情绪搜索。
    func fetchRecentDiaries(limit: Int, searchText: String?) throws -> [DiaryEntry]

    /// 更新收藏状态，并把记录标记为待同步更新。
    func updateFavorite(id: UUID, isFavorite: Bool) throws

    /// 更新日记内容和元数据，并刷新更新时间与同步状态。
    func updateDiary(_ diary: DiaryEntry) throws

    /// 软删除日记，并清理其附件和标签关系。
    func softDeleteDiary(id: UUID) throws
}

/// 基于 Core Data 的日记仓储。
/// 负责日记实体和领域模型之间的映射，并维护软删除与同步状态。
final class DiaryRepository: DiaryRepositoryProtocol {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    @discardableResult
    func save(_ diary: DiaryEntry) throws -> DiaryEntry {
        // localId 是本地稳定身份：重复保存同一 localId 时更新原对象，避免创建重复记录。
        let object = try existingObject(id: diary.localId) ?? NSEntityDescription.insertNewObject(forEntityName: "DiaryEntryEntity", into: context)

        object.setValue(diary.localId, forKey: "localId")
        object.setValue(diary.content, forKey: "content")
        object.setValue(diary.mood.rawValue, forKey: "mood")
        object.setValue(diary.entryDate, forKey: "entryDate")
        object.setValue(diary.isFavorite, forKey: "isFavorite")
        object.setValue(diary.isDraft, forKey: "isDraft")
        CoreDataValueMapper.apply(diary.location, to: object)
        CoreDataValueMapper.apply(diary.weather, to: object)
        CoreDataValueMapper.applySyncFields(
            to: object,
            remoteId: diary.remoteId,
            createdAt: diary.createdAt,
            updatedAt: Date(),
            deletedAt: diary.deletedAt,
            syncStatus: diary.syncStatus
        )

        try context.save()
        return try mapDiary(object)
    }

    func fetchDiary(id: UUID) throws -> DiaryEntry? {
        guard let object = try existingObject(id: id) else { return nil }
        return try mapDiary(object)
    }

    func fetchDiaries(on date: Date, calendar: Calendar = .current) throws -> [DiaryEntry] {
        let interval = dayInterval(for: date, calendar: calendar)
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND entryDate >= %@ AND entryDate < %@", interval.start as NSDate, interval.end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "entryDate", ascending: false)]
        return try context.fetch(request).map(mapDiary)
    }

    func fetchLatestDiary(on date: Date, calendar: Calendar = .current) throws -> DiaryEntry? {
        let interval = dayInterval(for: date, calendar: calendar)
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND isDraft == NO AND entryDate >= %@ AND entryDate < %@", interval.start as NSDate, interval.end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "entryDate", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first.map(mapDiary)
    }

    func fetchRecentDiaries(limit: Int = 50, searchText: String? = nil) throws -> [DiaryEntry] {
        let request = baseFetchRequest()
        var predicates = [NSPredicate(format: "deletedAt == nil")]

        if let searchText, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            // 搜索同时覆盖正文、地点和情绪，匹配日记列表的组合筛选体验。
            predicates.append(NSPredicate(format: "content CONTAINS[cd] %@ OR locationName CONTAINS[cd] %@ OR city CONTAINS[cd] %@ OR district CONTAINS[cd] %@ OR mood CONTAINS[cd] %@", query, query, query, query, query))
        }

        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "entryDate", ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request).map(mapDiary)
    }

    func softDeleteDiary(id: UUID) throws {
        guard let object = try existingObject(id: id) else { return }
        let now = Date()
        object.setValue(now, forKey: "deletedAt")
        object.setValue(now, forKey: "updatedAt")
        object.setValue(SyncStatus.pendingDelete.rawValue, forKey: "syncStatus")
        // 日记删除需要同步清理本地从属资源，避免附件文件和标签关系孤留在界面上。
        try AttachmentRepository(context: context).softDeleteAttachments(ownerId: id, ownerType: .diary)
        try TagRepository(context: context).replaceTags(forDiaryId: id, with: [])
        try context.save()
    }

    func updateFavorite(id: UUID, isFavorite: Bool) throws {
        guard let object = try existingObject(id: id) else { return }
        object.setValue(isFavorite, forKey: "isFavorite")
        object.setValue(Date(), forKey: "updatedAt")
        object.setValue(SyncStatus.pendingUpdate.rawValue, forKey: "syncStatus")
        try context.save()
    }

    func updateDiary(_ diary: DiaryEntry) throws {
        var updatedDiary = diary
        updatedDiary.updatedAt = Date()
        updatedDiary.syncStatus = .pendingUpdate
        try save(updatedDiary)
    }

    private func existingObject(id: UUID) throws -> NSManagedObject? {
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func baseFetchRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: "DiaryEntryEntity")
    }

    private func dayInterval(for date: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    private func mapDiary(_ object: NSManagedObject) throws -> DiaryEntry {
        // 必填字段缺失说明 Core Data 模型或迁移有问题，向上抛出仓储错误便于测试定位。
        guard
            let localId = object.value(forKey: "localId") as? UUID,
            let content = object.value(forKey: "content") as? String,
            let moodRawValue = object.value(forKey: "mood") as? String,
            let mood = MoodType(rawValue: moodRawValue),
            let entryDate = object.value(forKey: "entryDate") as? Date,
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let updatedAt = object.value(forKey: "updatedAt") as? Date
        else {
            throw RepositoryError.invalidStoredObject(entityName: "DiaryEntryEntity")
        }

        let syncStatusRawValue = object.value(forKey: "syncStatus") as? String
        return DiaryEntry(
            localId: localId,
            remoteId: object.value(forKey: "remoteId") as? String,
            content: content,
            mood: mood,
            entryDate: entryDate,
            location: CoreDataValueMapper.location(from: object),
            weather: CoreDataValueMapper.weather(from: object),
            isFavorite: object.value(forKey: "isFavorite") as? Bool ?? false,
            isDraft: object.value(forKey: "isDraft") as? Bool ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: object.value(forKey: "deletedAt") as? Date,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}
