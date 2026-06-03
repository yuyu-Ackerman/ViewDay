import XCTest
@testable import ViewDay

final class RepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        stack = CoreDataStack(inMemory: true)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDownWithError() throws {
        stack = nil
        calendar = nil
    }

    func testDefaultDataSeederCreatesDefaultAccountOnce() throws {
        let seeder = DefaultDataSeeder(context: stack.viewContext)

        try seeder.seedIfNeeded()
        try seeder.seedIfNeeded()

        let account = try AccountRepository(context: stack.viewContext).fetchDefaultAccount()
        XCTAssertEqual(account?.name, "默认账户")
        XCTAssertEqual(account?.isDefault, true)
    }

    func testDiaryRepositorySavesFetchesAndSoftDeletesDiary() throws {
        let repository = DiaryRepository(context: stack.viewContext)
        let diary = makeDiary(content: "今天在江边散步。")

        let saved = try repository.save(diary)
        XCTAssertEqual(saved.content, diary.content)

        let fetched = try repository.fetchLatestDiary(on: diary.entryDate, calendar: calendar)
        XCTAssertEqual(fetched?.localId, diary.localId)

        try repository.softDeleteDiary(id: diary.localId)
        let deletedFetch = try repository.fetchLatestDiary(on: diary.entryDate, calendar: calendar)
        XCTAssertNil(deletedFetch)
    }

    func testDiaryRepositoryUpdatesFavorite() throws {
        let repository = DiaryRepository(context: stack.viewContext)
        let diary = try repository.save(makeDiary(content: "值得收藏"))

        try repository.updateFavorite(id: diary.localId, isFavorite: true)

        let fetched = try repository.fetchDiary(id: diary.localId)
        XCTAssertEqual(fetched?.isFavorite, true)
        XCTAssertEqual(fetched?.syncStatus, .pendingUpdate)
    }

    func testDiaryRepositoryUpdatesDiaryContentAndMood() throws {
        let repository = DiaryRepository(context: stack.viewContext)
        var diary = try repository.save(makeDiary(content: "原始内容"))
        diary.content = "更新内容"
        diary.mood = .happy

        try repository.updateDiary(diary)

        let fetched = try repository.fetchDiary(id: diary.localId)
        XCTAssertEqual(fetched?.content, "更新内容")
        XCTAssertEqual(fetched?.mood, .happy)
        XCTAssertEqual(fetched?.syncStatus, .pendingUpdate)
    }

    func testTransactionRepositorySavesFetchesAndSoftDeletesTransaction() throws {
        let repository = TransactionRepository(context: stack.viewContext)
        let transaction = makeTransaction(amount: 128, type: .expense, category: .food)

        let saved = try repository.save(transaction)
        XCTAssertEqual(saved.amount, 128)

        let fetched = try repository.fetchLatestTransaction(on: transaction.transactionDate, calendar: calendar)
        XCTAssertEqual(fetched?.localId, transaction.localId)

        try repository.softDeleteTransaction(id: transaction.localId)
        let deletedFetch = try repository.fetchLatestTransaction(on: transaction.transactionDate, calendar: calendar)
        XCTAssertNil(deletedFetch)
    }

    func testTransactionRepositoryUpdatesTransaction() throws {
        let repository = TransactionRepository(context: stack.viewContext)
        var transaction = try repository.save(makeTransaction(amount: 128, type: .expense, category: .food))
        transaction.amount = 256
        transaction.category = .shopping
        transaction.note = "更新后的账单"

        try repository.updateTransaction(transaction)

        let fetched = try repository.fetchTransaction(id: transaction.localId)
        XCTAssertEqual(fetched?.amount, 256)
        XCTAssertEqual(fetched?.category, .shopping)
        XCTAssertEqual(fetched?.note, "更新后的账单")
        XCTAssertEqual(fetched?.syncStatus, .pendingUpdate)
    }

    func testTransactionRepositoryFetchesTransactionsByMonth() throws {
        let repository = TransactionRepository(context: stack.viewContext)
        let mayDate = Date(timeIntervalSince1970: 1_769_472_000)
        let juneDate = Calendar(identifier: .gregorian).date(byAdding: .month, value: 1, to: mayDate)!

        try repository.save(makeTransaction(amount: 128, type: .expense, category: .food, date: mayDate))
        try repository.save(makeTransaction(amount: 256, type: .expense, category: .shopping, date: juneDate))

        let mayTransactions = try repository.fetchTransactions(inMonthContaining: mayDate, calendar: calendar)

        XCTAssertEqual(mayTransactions.count, 1)
        XCTAssertEqual(mayTransactions.first?.amount, 128)
    }

    func testDeletingDiaryAlsoDeletesAttachmentFiles() throws {
        let diaryRepository = DiaryRepository(context: stack.viewContext)
        let attachmentRepository = AttachmentRepository(context: stack.viewContext)
        let diary = try diaryRepository.save(makeDiary(content: "有图片的日记"))
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try Data("image".utf8).write(to: fileURL)

        let now = Date()
        let attachment = Attachment(
            localId: UUID(),
            remoteId: nil,
            ownerId: diary.localId,
            ownerType: .diary,
            type: .image,
            localFilePath: fileURL.path,
            remoteURL: nil,
            fileName: fileURL.lastPathComponent,
            mimeType: "image/jpeg",
            fileSize: 5,
            duration: nil,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        )
        try attachmentRepository.save(attachment)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try diaryRepository.softDeleteDiary(id: diary.localId)

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let attachments = try attachmentRepository.fetchAttachments(ownerId: diary.localId, ownerType: .diary)
        XCTAssertTrue(attachments.isEmpty)
    }

    func testAttachmentRepositoryFetchesOwnerIdsByAttachmentType() throws {
        let diaryRepository = DiaryRepository(context: stack.viewContext)
        let attachmentRepository = AttachmentRepository(context: stack.viewContext)
        let diary = try diaryRepository.save(makeDiary(content: "图文日记"))
        let now = Date()

        try attachmentRepository.save(Attachment(
            localId: UUID(),
            remoteId: nil,
            ownerId: diary.localId,
            ownerType: .diary,
            type: .image,
            localFilePath: "/tmp/example.jpg",
            remoteURL: nil,
            fileName: "example.jpg",
            mimeType: "image/jpeg",
            fileSize: nil,
            duration: nil,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        ))

        let ownerIds = try attachmentRepository.fetchOwnerIdsWithAttachments(ownerType: .diary, attachmentType: .image)
        XCTAssertTrue(ownerIds.contains(diary.localId))
    }

    func testAttachmentRepositorySoftDeletesOnlyRequestedType() throws {
        let diaryRepository = DiaryRepository(context: stack.viewContext)
        let attachmentRepository = AttachmentRepository(context: stack.viewContext)
        let diary = try diaryRepository.save(makeDiary(content: "带图片和语音的日记"))
        let now = Date()

        try attachmentRepository.save(Attachment(
            localId: UUID(),
            remoteId: nil,
            ownerId: diary.localId,
            ownerType: .diary,
            type: .image,
            localFilePath: "/tmp/example.jpg",
            remoteURL: nil,
            fileName: "example.jpg",
            mimeType: "image/jpeg",
            fileSize: nil,
            duration: nil,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        ))
        try attachmentRepository.save(Attachment(
            localId: UUID(),
            remoteId: nil,
            ownerId: diary.localId,
            ownerType: .diary,
            type: .audio,
            localFilePath: "/tmp/example.m4a",
            remoteURL: nil,
            fileName: "example.m4a",
            mimeType: "audio/mp4",
            fileSize: nil,
            duration: nil,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        ))

        try attachmentRepository.softDeleteAttachments(ownerId: diary.localId, ownerType: .diary, attachmentType: .image)

        let attachments = try attachmentRepository.fetchAttachments(ownerId: diary.localId, ownerType: .diary)
        XCTAssertEqual(attachments.map(\.type), [.audio])
    }

    func testTagRepositoryCreatesTagsAndReplacesDiaryRelations() throws {
        let diaryRepository = DiaryRepository(context: stack.viewContext)
        let tagRepository = TagRepository(context: stack.viewContext)
        let diary = try diaryRepository.save(makeDiary(content: "带标签的日记"))

        let walk = try tagRepository.saveTag(name: "散步")
        let life = try tagRepository.saveTag(name: "生活")
        try tagRepository.replaceTags(forDiaryId: diary.localId, with: [walk, life])

        var tags = try tagRepository.fetchTags(forDiaryId: diary.localId)
        XCTAssertEqual(Set(tags.map(\.name)), ["散步", "生活"])

        try tagRepository.replaceTags(forDiaryId: diary.localId, with: [life])
        tags = try tagRepository.fetchTags(forDiaryId: diary.localId)
        XCTAssertEqual(tags.map(\.name), ["生活"])
    }

    func testDeletingDiaryRemovesTagRelationsButKeepsTags() throws {
        let diaryRepository = DiaryRepository(context: stack.viewContext)
        let tagRepository = TagRepository(context: stack.viewContext)
        let diary = try diaryRepository.save(makeDiary(content: "稍后删除的标签日记"))
        let tag = try tagRepository.saveTag(name: "工作")
        try tagRepository.replaceTags(forDiaryId: diary.localId, with: [tag])

        try diaryRepository.softDeleteDiary(id: diary.localId)

        XCTAssertTrue(try tagRepository.fetchTags(forDiaryId: diary.localId).isEmpty)
        XCTAssertTrue(try tagRepository.fetchAllTags().contains { $0.name == "工作" })
    }

    func testDailyOverviewSummarizesIncomeExpenseAndLatestItems() throws {
        let diaryRepository = DiaryRepository(context: stack.viewContext)
        let transactionRepository = TransactionRepository(context: stack.viewContext)
        let dashboardRepository = DashboardRepository(
            diaryRepository: diaryRepository,
            transactionRepository: transactionRepository,
            calendar: calendar
        )
        let date = Date(timeIntervalSince1970: 1_769_472_000)

        try diaryRepository.save(makeDiary(content: "今天很好。", date: date))
        try diaryRepository.save(makeDiary(content: "第二篇日记。", date: date.addingTimeInterval(120)))
        try transactionRepository.save(makeTransaction(amount: 128, type: .expense, category: .food, date: date))
        try transactionRepository.save(makeTransaction(amount: 300, type: .income, category: .gift, date: date.addingTimeInterval(60)))

        let overview = try dashboardRepository.dailyOverview(for: date)

        XCTAssertEqual(overview.latestDiary?.content, "第二篇日记。")
        XCTAssertEqual(overview.diaries.map(\.content), ["第二篇日记。", "今天很好。"])
        XCTAssertEqual(overview.todayIncome, 300)
        XCTAssertEqual(overview.todayExpense, 128)
        XCTAssertEqual(overview.todayBalance, 172)
        XCTAssertEqual(overview.latestTransaction?.type, .income)
    }

    func testDashboardSummariesIgnoreDraftTransactions() throws {
        let transactionRepository = TransactionRepository(context: stack.viewContext)
        let dashboardRepository = DashboardRepository(
            diaryRepository: DiaryRepository(context: stack.viewContext),
            transactionRepository: transactionRepository,
            calendar: calendar
        )
        let date = Date(timeIntervalSince1970: 1_769_472_000)

        try transactionRepository.save(makeTransaction(amount: 100, type: .expense, category: .food, date: date))
        try transactionRepository.save(makeTransaction(amount: 999, type: .expense, category: .shopping, date: date, isDraft: true))
        try transactionRepository.save(makeTransaction(amount: 500, type: .income, category: .gift, date: date))
        try transactionRepository.save(makeTransaction(amount: 888, type: .income, category: .salary, date: date, isDraft: true))

        let overview = try dashboardRepository.dailyOverview(for: date)
        let monthlySummary = try dashboardRepository.monthlyLedgerSummary(for: date)

        XCTAssertEqual(overview.todayIncome, 500)
        XCTAssertEqual(overview.todayExpense, 100)
        XCTAssertEqual(overview.todayBalance, 400)
        XCTAssertEqual(monthlySummary.income, 500)
        XCTAssertEqual(monthlySummary.expense, 100)
        XCTAssertEqual(monthlySummary.balance, 400)
        XCTAssertEqual(monthlySummary.categorySummaries.map(\.category), [.food])
    }

    private func makeDiary(content: String, date: Date = Date(timeIntervalSince1970: 1_769_472_000)) -> DiaryEntry {
        let now = Date()
        return DiaryEntry(
            localId: UUID(),
            remoteId: nil,
            content: content,
            mood: .calm,
            entryDate: date,
            location: LocationSnapshot(name: "江边", city: "重庆市", district: "南岸区", address: nil, latitude: nil, longitude: nil, isManuallyEdited: false),
            weather: WeatherSnapshot(temperature: 22, condition: "晴", conditionCode: nil, humidity: nil, windSpeed: nil, provider: "WeatherKit", fetchedAt: now),
            isFavorite: false,
            isDraft: false,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        )
    }

    private func makeTransaction(
        amount: Decimal,
        type: TransactionType,
        category: TransactionCategory,
        date: Date = Date(timeIntervalSince1970: 1_769_472_000),
        isDraft: Bool = false
    ) -> LedgerTransaction {
        let now = Date()
        return LedgerTransaction(
            localId: UUID(),
            remoteId: nil,
            amount: amount,
            type: type,
            category: category,
            accountId: nil,
            note: "测试账单",
            detailText: nil,
            transactionDate: date,
            location: nil,
            weather: nil,
            isDraft: isDraft,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .localOnly
        )
    }
}
