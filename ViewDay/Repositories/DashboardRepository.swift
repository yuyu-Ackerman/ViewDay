import Foundation

/// 首页和账本概览仓储。
/// 该仓储不直接访问 Core Data，而是组合日记和流水仓储生成跨模块展示模型。
final class DashboardRepository {
    private let diaryRepository: DiaryRepositoryProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let calendar: Calendar

    init(
        diaryRepository: DiaryRepositoryProtocol = DiaryRepository(),
        transactionRepository: TransactionRepositoryProtocol = TransactionRepository(),
        calendar: Calendar = .current
    ) {
        self.diaryRepository = diaryRepository
        self.transactionRepository = transactionRepository
        self.calendar = calendar
    }

    func dailyOverview(for date: Date) throws -> DailyOverview {
        // 首页只展示正式记录；草稿仍保存在仓储中，但不参与当天摘要统计。
        let diaries = try diaryRepository.fetchDiaries(on: date, calendar: calendar)
            .filter { !$0.isDraft }
        let latestDiary = diaries.first
        let transactions = try transactionRepository.fetchTransactions(on: date, calendar: calendar)
        let income = transactions
            .filter { $0.type == .income && !$0.isDraft }
            .map(\.amount)
            .reduce(Decimal.zero, +)
        let expense = transactions
            .filter { $0.type == .expense && !$0.isDraft }
            .map(\.amount)
            .reduce(Decimal.zero, +)

        return DailyOverview(
            date: date,
            // 当天上下文优先取最新日记；没有日记时使用最新流水，让首页始终有地点和天气线索。
            location: latestDiary?.location ?? transactions.first?.location,
            weather: latestDiary?.weather ?? transactions.first?.weather,
            latestDiary: latestDiary,
            diaries: diaries,
            todayIncome: income,
            todayExpense: expense,
            todayBalance: income - expense,
            latestTransaction: transactions.first(where: { !$0.isDraft })
        )
    }

    func monthlyLedgerSummary(for date: Date) throws -> MonthlyLedgerSummary {
        let interval = monthInterval(containing: date)
        // 月账本统计排除草稿，避免未完成录入影响收入、支出和图表。
        let transactions = try transactionRepository.fetchTransactions(in: interval)
            .filter { !$0.isDraft }
        let incomeTransactions = transactions.filter { $0.type == .income }
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let income = incomeTransactions.map(\.amount).reduce(Decimal.zero, +)
        let expense = expenseTransactions.map(\.amount).reduce(Decimal.zero, +)
        let categorySummaries = makeCategorySummaries(from: expenseTransactions, total: expense)

        return MonthlyLedgerSummary(
            month: interval.start,
            income: income,
            expense: expense,
            balance: income - expense,
            categorySummaries: categorySummaries,
            dailyBalancePoints: makeDailyBalancePoints(from: transactions, interval: interval)
        )
    }

    private func monthInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }

    private func makeCategorySummaries(from transactions: [LedgerTransaction], total: Decimal) -> [CategorySummary] {
        let grouped = Dictionary(grouping: transactions, by: \.category)
        return grouped
            .map { category, items in
                let amount = items.map(\.amount).reduce(Decimal.zero, +)
                let percentage = total == .zero ? 0 : NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: total).doubleValue
                return CategorySummary(category: category, amount: amount, percentage: percentage)
            }
            .sorted { $0.amount > $1.amount }
    }

    private func makeDailyBalancePoints(from transactions: [LedgerTransaction], interval: DateInterval) -> [DailyBalancePoint] {
        guard let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day else {
            return []
        }

        var runningBalance = Decimal.zero

        // 图表展示的是月内累计余额，所以每天以前一日余额为基础继续累加。
        return (0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let dayTransactions = transactions.filter { $0.transactionDate >= day && $0.transactionDate < nextDay }
            let income = dayTransactions.filter { $0.type == .income }.map(\.amount).reduce(Decimal.zero, +)
            let expense = dayTransactions.filter { $0.type == .expense }.map(\.amount).reduce(Decimal.zero, +)
            runningBalance += income - expense
            return DailyBalancePoint(date: day, balance: runningBalance)
        }
    }
}
