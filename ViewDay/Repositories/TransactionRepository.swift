import CoreData
import Foundation

/// 账本流水仓储协议。
/// 提供按天、按月和最近记录查询，供首页、账本页和详情页复用。
protocol TransactionRepositoryProtocol {
    @discardableResult
    func save(_ transaction: LedgerTransaction) throws -> LedgerTransaction
    func fetchTransaction(id: UUID) throws -> LedgerTransaction?
    func fetchTransactions(on date: Date, calendar: Calendar) throws -> [LedgerTransaction]
    func fetchTransactions(in interval: DateInterval) throws -> [LedgerTransaction]
    func fetchTransactions(inMonthContaining date: Date, calendar: Calendar) throws -> [LedgerTransaction]
    func fetchRecentTransactions(limit: Int) throws -> [LedgerTransaction]
    func fetchLatestTransaction(on date: Date, calendar: Calendar) throws -> LedgerTransaction?
    func updateTransaction(_ transaction: LedgerTransaction) throws
    func softDeleteTransaction(id: UUID) throws
}

/// 基于 Core Data 的账本流水仓储。
/// 负责保存流水、维护软删除状态，并把实体映射为领域模型。
final class TransactionRepository: TransactionRepositoryProtocol {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self.context = context
    }

    @discardableResult
    func save(_ transaction: LedgerTransaction) throws -> LedgerTransaction {
        // localId 是本地稳定身份：重复保存同一 localId 时更新原对象，避免创建重复流水。
        let object = try existingObject(id: transaction.localId) ?? NSEntityDescription.insertNewObject(forEntityName: "LedgerTransactionEntity", into: context)

        object.setValue(transaction.localId, forKey: "localId")
        object.setValue(NSDecimalNumber(decimal: transaction.amount), forKey: "amount")
        object.setValue(transaction.type.rawValue, forKey: "type")
        object.setValue(transaction.category.rawValue, forKey: "category")
        object.setValue(transaction.accountId, forKey: "accountId")
        object.setValue(transaction.note, forKey: "note")
        object.setValue(transaction.detailText, forKey: "detailText")
        object.setValue(transaction.transactionDate, forKey: "transactionDate")
        object.setValue(transaction.isDraft, forKey: "isDraft")
        CoreDataValueMapper.apply(transaction.location, to: object)
        CoreDataValueMapper.apply(transaction.weather, to: object)
        CoreDataValueMapper.applySyncFields(
            to: object,
            remoteId: transaction.remoteId,
            createdAt: transaction.createdAt,
            updatedAt: Date(),
            deletedAt: transaction.deletedAt,
            syncStatus: transaction.syncStatus
        )

        try context.save()
        return try mapTransaction(object)
    }

    func fetchTransaction(id: UUID) throws -> LedgerTransaction? {
        guard let object = try existingObject(id: id) else { return nil }
        return try mapTransaction(object)
    }

    func fetchTransactions(on date: Date, calendar: Calendar = .current) throws -> [LedgerTransaction] {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return try fetchTransactions(in: DateInterval(start: start, end: end))
    }

    func fetchTransactions(in interval: DateInterval) throws -> [LedgerTransaction] {
        let request = baseFetchRequest()
        // 使用半开区间避免跨天或跨月边界重复统计同一笔流水。
        request.predicate = NSPredicate(format: "deletedAt == nil AND transactionDate >= %@ AND transactionDate < %@", interval.start as NSDate, interval.end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "transactionDate", ascending: false)]
        return try context.fetch(request).map(mapTransaction)
    }

    func fetchLatestTransaction(on date: Date, calendar: Calendar = .current) throws -> LedgerTransaction? {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND isDraft == NO AND transactionDate >= %@ AND transactionDate < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "transactionDate", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first.map(mapTransaction)
    }

    func fetchRecentTransactions(limit: Int = 50) throws -> [LedgerTransaction] {
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "deletedAt == nil AND isDraft == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "transactionDate", ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request).map(mapTransaction)
    }

    func fetchTransactions(inMonthContaining date: Date, calendar: Calendar = .current) throws -> [LedgerTransaction] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }

        return try fetchTransactions(in: interval)
    }

    func softDeleteTransaction(id: UUID) throws {
        guard let object = try existingObject(id: id) else { return }
        let now = Date()
        object.setValue(now, forKey: "deletedAt")
        object.setValue(now, forKey: "updatedAt")
        object.setValue(SyncStatus.pendingDelete.rawValue, forKey: "syncStatus")
        // 删除流水时同步清理附件，保持账本列表和文件系统状态一致。
        try AttachmentRepository(context: context).softDeleteAttachments(ownerId: id, ownerType: .transaction)
        try context.save()
    }

    func updateTransaction(_ transaction: LedgerTransaction) throws {
        var updatedTransaction = transaction
        updatedTransaction.updatedAt = Date()
        updatedTransaction.syncStatus = .pendingUpdate
        try save(updatedTransaction)
    }

    private func existingObject(id: UUID) throws -> NSManagedObject? {
        let request = baseFetchRequest()
        request.predicate = NSPredicate(format: "localId == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func baseFetchRequest() -> NSFetchRequest<NSManagedObject> {
        NSFetchRequest<NSManagedObject>(entityName: "LedgerTransactionEntity")
    }

    private func mapTransaction(_ object: NSManagedObject) throws -> LedgerTransaction {
        // 必填字段缺失说明 Core Data 模型或迁移有问题，向上抛出仓储错误便于测试定位。
        guard
            let localId = object.value(forKey: "localId") as? UUID,
            let amountNumber = object.value(forKey: "amount") as? NSDecimalNumber,
            let typeRawValue = object.value(forKey: "type") as? String,
            let type = TransactionType(rawValue: typeRawValue),
            let categoryRawValue = object.value(forKey: "category") as? String,
            let category = TransactionCategory(rawValue: categoryRawValue),
            let transactionDate = object.value(forKey: "transactionDate") as? Date,
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let updatedAt = object.value(forKey: "updatedAt") as? Date
        else {
            throw RepositoryError.invalidStoredObject(entityName: "LedgerTransactionEntity")
        }

        let syncStatusRawValue = object.value(forKey: "syncStatus") as? String
        return LedgerTransaction(
            localId: localId,
            remoteId: object.value(forKey: "remoteId") as? String,
            amount: amountNumber.decimalValue,
            type: type,
            category: category,
            accountId: object.value(forKey: "accountId") as? UUID,
            note: object.value(forKey: "note") as? String,
            detailText: object.value(forKey: "detailText") as? String,
            transactionDate: transactionDate,
            location: CoreDataValueMapper.location(from: object),
            weather: CoreDataValueMapper.weather(from: object),
            isDraft: object.value(forKey: "isDraft") as? Bool ?? false,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: object.value(forKey: "deletedAt") as? Date,
            syncStatus: SyncStatus(rawValue: syncStatusRawValue ?? "") ?? .localOnly
        )
    }
}
