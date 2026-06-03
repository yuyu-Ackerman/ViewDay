import SnapKit
import UIKit

/// 账本日期筛选范围。
/// 月视图用于统计概览，日视图用于从首页跳转后聚焦当天流水。
private enum LedgerDateScope: Int {
    case month
    case day
}

/// 账本首页控制器。
/// 展示月度统计、分类占比、余额走势和流水列表，并支持按日期过滤。
final class LedgerViewController: ViewDayBaseViewController {
    private let dashboardRepository: DashboardRepository
    private let transactionRepository: TransactionRepositoryProtocol

    private let pageTitleLabel = UILabel()
    private let filterButton = UIButton(type: .system)
    private let dateScopeControl = UISegmentedControl(items: ["按月", "按日"])
    private let periodButton = UIButton(type: .system)
    private let summaryCardView = LedgerSummaryCardView()
    private let modeSegmentView = LedgerModeSegmentView()
    private let balanceChartView = LedgerBalanceChartView()
    private let categoryBarsView = LedgerCategoryBarsView()
    private let transactionListCardView = UIView()
    private let transactionTitleLabel = UILabel()
    private let viewAllTransactionsButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateLabel = UILabel()
    private let addButton = UIButton(type: .system)

    private var selectedMode: LedgerMode = .overview
    private var selectedDateScope: LedgerDateScope
    private var selectedMonth: Date
    private var selectedDateFilter: Date?
    private var selectedCategory: TransactionCategory?
    private var summary: MonthlyLedgerSummary?
    private var transactions: [LedgerTransaction] = []
    private weak var presentedDatePicker: UIDatePicker?

    init(
        selectedMonth: Date = Date(),
        selectedDateFilter: Date? = nil,
        dashboardRepository: DashboardRepository = DashboardRepository(),
        transactionRepository: TransactionRepositoryProtocol = TransactionRepository()
    ) {
        self.selectedMonth = selectedMonth
        self.selectedDateFilter = selectedDateFilter
        selectedDateScope = selectedDateFilter == nil ? .month : .day
        self.dashboardRepository = dashboardRepository
        self.transactionRepository = transactionRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        modeSegmentView.delegate = self
        setupContent()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reloadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupContent() {
        setupHeader()
        setupTransactionListCard()
        setupAddButton()

        contentView.addSubview(pageTitleLabel)
        contentView.addSubview(filterButton)
        contentView.addSubview(dateScopeControl)
        contentView.addSubview(periodButton)
        contentView.addSubview(summaryCardView)
        contentView.addSubview(modeSegmentView)
        contentView.addSubview(balanceChartView)
        contentView.addSubview(categoryBarsView)
        contentView.addSubview(transactionListCardView)

        pageTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(filterButton.snp.leading).offset(-12)
        }

        filterButton.snp.makeConstraints { make in
            make.centerY.equalTo(pageTitleLabel)
            make.trailing.equalToSuperview().inset(20)
            make.width.height.equalTo(40)
        }

        dateScopeControl.snp.makeConstraints { make in
            make.centerY.equalTo(periodButton)
            make.trailing.equalToSuperview().inset(20)
            make.width.equalTo(116)
            make.height.equalTo(32)
        }

        periodButton.snp.makeConstraints { make in
            make.top.equalTo(pageTitleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(dateScopeControl.snp.leading).offset(-10)
            make.height.equalTo(32)
        }

        summaryCardView.snp.makeConstraints { make in
            make.top.equalTo(periodButton.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        modeSegmentView.snp.makeConstraints { make in
            make.top.equalTo(summaryCardView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }

        categoryBarsView.snp.makeConstraints { make in
            make.top.equalTo(modeSegmentView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        balanceChartView.snp.makeConstraints { make in
            make.top.equalTo(categoryBarsView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        transactionListCardView.snp.makeConstraints { make in
            make.top.equalTo(balanceChartView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(352)
            make.bottom.equalToSuperview().inset(96)
        }
    }

    private func setupHeader() {
        pageTitleLabel.text = "账本"
        pageTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        pageTitleLabel.textColor = ViewDayTheme.primaryText

        filterButton.backgroundColor = ViewDayTheme.controlBackground
        filterButton.tintColor = ViewDayTheme.iconPrimary
        filterButton.layer.cornerRadius = 12
        filterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        filterButton.addTarget(self, action: #selector(filterButtonTapped), for: .touchUpInside)

        dateScopeControl.selectedSegmentIndex = selectedDateScope.rawValue
        dateScopeControl.selectedSegmentTintColor = ViewDayTheme.accent
        dateScopeControl.backgroundColor = ViewDayTheme.controlBackground
        dateScopeControl.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: ViewDayTheme.secondaryText
        ], for: .normal)
        dateScopeControl.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: UIColor.black
        ], for: .selected)
        dateScopeControl.addTarget(self, action: #selector(dateScopeChanged(_:)), for: .valueChanged)

        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 10)
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.baseForegroundColor = ViewDayTheme.primaryText
        configuration.baseBackgroundColor = ViewDayTheme.cardBackground
        periodButton.configuration = configuration
        periodButton.layer.cornerRadius = 8
        periodButton.layer.borderWidth = 1
        periodButton.layer.borderColor = ViewDayTheme.border.cgColor
        periodButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        periodButton.addTarget(self, action: #selector(periodButtonTapped), for: .touchUpInside)
    }

    private func setupTransactionListCard() {
        transactionListCardView.backgroundColor = ViewDayTheme.cardBackground
        transactionListCardView.layer.cornerRadius = 8
        transactionListCardView.layer.borderWidth = 1
        transactionListCardView.layer.borderColor = ViewDayTheme.border.cgColor

        transactionTitleLabel.text = "最近账单"
        transactionTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        transactionTitleLabel.textColor = ViewDayTheme.primaryText

        var viewAllConfiguration = UIButton.Configuration.plain()
        viewAllConfiguration.title = "查看全部"
        viewAllConfiguration.image = UIImage(systemName: "chevron.right")
        viewAllConfiguration.imagePlacement = .trailing
        viewAllConfiguration.imagePadding = 3
        viewAllConfiguration.contentInsets = .zero
        viewAllConfiguration.baseForegroundColor = ViewDayTheme.secondaryText
        viewAllTransactionsButton.configuration = viewAllConfiguration
        viewAllTransactionsButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        viewAllTransactionsButton.addTarget(self, action: #selector(viewAllTransactionsButtonTapped), for: .touchUpInside)

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LedgerTransactionCell.self, forCellReuseIdentifier: LedgerTransactionCell.reuseIdentifier)

        emptyStateLabel.text = "还没有账单"
        emptyStateLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        emptyStateLabel.textColor = ViewDayTheme.secondaryText
        emptyStateLabel.textAlignment = .center

        transactionListCardView.addSubview(transactionTitleLabel)
        transactionListCardView.addSubview(viewAllTransactionsButton)
        transactionListCardView.addSubview(tableView)
        transactionListCardView.addSubview(emptyStateLabel)

        transactionTitleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(viewAllTransactionsButton.snp.leading).offset(-12)
        }

        viewAllTransactionsButton.snp.makeConstraints { make in
            make.centerY.equalTo(transactionTitleLabel)
            make.trailing.equalToSuperview().inset(16)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(transactionTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupAddButton() {
        addButton.backgroundColor = ViewDayTheme.accent
        addButton.tintColor = .black
        addButton.layer.cornerRadius = 28
        addButton.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)), for: .normal)
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)

        view.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
            make.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
    }

    private func reloadData() {
        do {
            summary = try dashboardRepository.monthlyLedgerSummary(for: selectedMonth)
            transactions = try transactionRepository.fetchTransactions(inMonthContaining: selectedMonth, calendar: .current)
        } catch {
            summary = MonthlyLedgerSummary(month: selectedMonth, income: .zero, expense: .zero, balance: .zero, categorySummaries: [], dailyBalancePoints: [])
            transactions = []
        }

        applyMode()
    }

    private func applyMode() {
        guard let summary else { return }

        updatePeriodControl()
        let totals = visibleTotals()
        summaryCardView.configure(month: summary.month, income: totals.income, expense: totals.expense, balance: totals.balance)
        balanceChartView.configure(points: summary.dailyBalancePoints)
        transactionTitleLabel.text = listTitle()
        rebuildCategoryBars()
        tableView.reloadData()
        emptyStateLabel.isHidden = !filteredTransactions.isEmpty
        tableView.isHidden = filteredTransactions.isEmpty
        emptyStateLabel.text = selectedDateScope == .month ? "还没有账单" : "这一天还没有账单"
    }

    private func updatePeriodControl() {
        dateScopeControl.selectedSegmentIndex = selectedDateScope.rawValue
        var configuration = periodButton.configuration
        configuration?.title = selectedDateScope == .month ? monthText(selectedMonth) : shortDateText(activeDay)
        periodButton.configuration = configuration
    }

    private var activeDay: Date {
        selectedDateFilter ?? selectedMonth
    }

    private func visibleTotals() -> (income: Decimal, expense: Decimal, balance: Decimal) {
        guard selectedDateScope == .day else {
            return (summary?.income ?? .zero, summary?.expense ?? .zero, summary?.balance ?? .zero)
        }

        let dayTransactions = transactions.filter {
            !$0.isDraft && Calendar.current.isDate($0.transactionDate, inSameDayAs: activeDay)
        }
        let income = dayTransactions.filter { $0.type == .income }.map(\.amount).reduce(Decimal.zero, +)
        let expense = dayTransactions.filter { $0.type == .expense }.map(\.amount).reduce(Decimal.zero, +)
        return (income, expense, income - expense)
    }

    private func rebuildCategoryBars() {
        let title: String
        if let selectedCategory {
            title = "分类统计 · \(categoryText(selectedCategory))"
        } else {
            title = selectedMode == .income ? "收入分类" : "支出分类"
        }

        categoryBarsView.configure(title: title, summaries: visibleCategorySummaries())
    }

    private func visibleCategorySummaries() -> [CategorySummary] {
        guard let summary else { return [] }

        if selectedDateScope == .day {
            let sourceTransactions: [LedgerTransaction]
            switch selectedMode {
            case .overview, .expense:
                sourceTransactions = filteredTransactions.filter { $0.type == .expense }
            case .income:
                sourceTransactions = filteredTransactions.filter { $0.type == .income }
            }

            let grouped = Dictionary(grouping: sourceTransactions, by: \.category)
            let total = sourceTransactions.map(\.amount).reduce(Decimal.zero, +)
            return grouped.map { category, items in
                let amount = items.map(\.amount).reduce(Decimal.zero, +)
                let percentage = total == .zero ? 0 : NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: total).doubleValue
                return CategorySummary(category: category, amount: amount, percentage: percentage)
            }
            .sorted { $0.amount > $1.amount }
        }

        switch selectedMode {
        case .overview, .expense:
            let summaries = summary.categorySummaries
            guard let selectedCategory else { return summaries }
            return summaries.filter { $0.category == selectedCategory }
        case .income:
            let incomeTransactions = transactions.filter { !$0.isDraft && $0.type == .income }
            let total = incomeTransactions.map(\.amount).reduce(Decimal.zero, +)
            let grouped = Dictionary(grouping: incomeTransactions, by: \.category)
            let summaries = grouped.map { category, items in
                let amount = items.map(\.amount).reduce(Decimal.zero, +)
                let percentage = total == .zero ? 0 : NSDecimalNumber(decimal: amount).doubleValue / NSDecimalNumber(decimal: total).doubleValue
                return CategorySummary(category: category, amount: amount, percentage: percentage)
            }
            .sorted { $0.amount > $1.amount }

            guard let selectedCategory else { return summaries }
            return summaries.filter { $0.category == selectedCategory }
        }
    }

    private var filteredTransactions: [LedgerTransaction] {
        let savedTransactions = transactions.filter { !$0.isDraft }
        let modeFiltered: [LedgerTransaction]
        switch selectedMode {
        case .overview:
            modeFiltered = savedTransactions
        case .expense:
            modeFiltered = savedTransactions.filter { $0.type == .expense }
        case .income:
            modeFiltered = savedTransactions.filter { $0.type == .income }
        }

        let dateFiltered: [LedgerTransaction]
        if selectedDateScope == .day {
            dateFiltered = modeFiltered.filter { Calendar.current.isDate($0.transactionDate, inSameDayAs: activeDay) }
        } else {
            dateFiltered = modeFiltered
        }

        guard let selectedCategory else { return dateFiltered }
        return dateFiltered.filter { $0.category == selectedCategory }
    }

    private var previewTransactions: [LedgerTransaction] {
        Array(filteredTransactions.prefix(5))
    }

    private func listTitle() -> String {
        let baseTitle: String
        switch selectedMode {
        case .overview:
            baseTitle = selectedDateScope == .month ? "本月账单" : "本日账单"
        case .expense:
            baseTitle = selectedDateScope == .month ? "本月支出" : "本日支出"
        case .income:
            baseTitle = selectedDateScope == .month ? "本月收入" : "本日收入"
        }

        var parts = [baseTitle]
        if selectedDateScope == .day {
            parts.append(shortDateText(activeDay))
        }
        if let selectedCategory {
            parts.append(categoryText(selectedCategory))
        }
        return parts.joined(separator: " · ")
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }

    private func categoryText(_ category: TransactionCategory) -> String {
        switch category {
        case .food: return "餐饮"
        case .transport: return "交通"
        case .shopping: return "购物"
        case .entertainment: return "娱乐"
        case .home: return "居家"
        case .medical: return "医疗"
        case .salary: return "工资"
        case .partTime: return "兼职"
        case .gift: return "红包"
        case .investment: return "理财"
        case .other: return "其他"
        }
    }

    @objc private func addButtonTapped() {
        guard let tabBarController else { return }
        tabBarController.selectedIndex = 2

        guard let viewControllers = tabBarController.viewControllers, viewControllers.indices.contains(2) else { return }
        let recordNavigationController = viewControllers[2] as? UINavigationController
        let recordViewController = recordNavigationController?.viewControllers.first as? RecordViewController
        recordViewController?.showTransactionMode()
    }

    @objc private func filterButtonTapped() {
        let alertController = UIAlertController(title: "筛选分类", message: nil, preferredStyle: .actionSheet)
        let categories = categoriesForCurrentMode()

        categories.forEach { category in
            alertController.addAction(UIAlertAction(title: categoryText(category), style: .default) { [weak self] _ in
                self?.selectedCategory = category
                self?.applyMode()
            })
        }

        alertController.addAction(UIAlertAction(title: "全部分类", style: .default) { [weak self] _ in
            self?.selectedCategory = nil
            self?.applyMode()
        })
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alertController, animated: true)
    }

    @objc private func viewAllTransactionsButtonTapped() {
        let listViewController = LedgerTransactionListViewController(
            title: listTitle(),
            transactions: filteredTransactions,
            transactionRepository: transactionRepository
        )
        listViewController.onUpdate = { [weak self] in
            self?.reloadData()
        }
        navigationController?.pushViewController(listViewController, animated: true)
    }

    @objc private func dateScopeChanged(_ sender: UISegmentedControl) {
        guard let scope = LedgerDateScope(rawValue: sender.selectedSegmentIndex) else { return }
        selectedDateScope = scope
        selectedDateFilter = scope == .day ? activeDay : nil
        selectedCategory = nil
        applyMode()
    }

    @objc private func periodButtonTapped() {
        selectedDateScope == .month ? presentMonthPicker() : presentDatePicker()
    }

    private func presentDatePicker() {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = selectedDateFilter ?? selectedMonth
        presentedDatePicker = datePicker

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.edges.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择日期"
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissDatePicker))
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(applyPickedDateFilter))
        present(navigationController, animated: true)
    }

    private func presentMonthPicker() {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.date = selectedMonth
        presentedDatePicker = datePicker

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.leading.trailing.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
            make.centerY.equalToSuperview()
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择月份"
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissDatePicker))
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(applyPickedMonth))
        present(navigationController, animated: true)
    }

    @objc private func applyPickedMonth() {
        guard let pickedDate = presentedDatePicker?.date else {
            dismissDatePicker()
            return
        }
        selectedMonth = pickedDate
        selectedDateScope = .month
        selectedDateFilter = nil
        selectedCategory = nil
        dismissDatePicker()
        reloadData()
    }

    @objc private func dismissDatePicker() {
        presentedDatePicker = nil
        dismiss(animated: true)
    }

    @objc private func applyPickedDateFilter() {
        guard let pickedDate = presentedDatePicker?.date else {
            dismissDatePicker()
            return
        }

        selectedDateFilter = pickedDate
        selectedDateScope = .day
        if !Calendar.current.isDate(pickedDate, equalTo: selectedMonth, toGranularity: .month) {
            selectedMonth = pickedDate
            selectedCategory = nil
            dismissDatePicker()
            reloadData()
        } else {
            dismissDatePicker()
            applyMode()
        }
    }

    private func shortDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func monthText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func longDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func categoriesForCurrentMode() -> [TransactionCategory] {
        switch selectedMode {
        case .overview:
            return Array(Set(transactions.filter { !$0.isDraft }.map(\.category))).sorted { categoryText($0) < categoryText($1) }
        case .expense:
            return TransactionCategory.available(for: .expense)
        case .income:
            return TransactionCategory.available(for: .income)
        }
    }
}

extension LedgerViewController: LedgerModeSegmentViewDelegate {
    func ledgerModeSegmentView(_ view: LedgerModeSegmentView, didSelect mode: LedgerMode) {
        selectedMode = mode
        if let selectedCategory, !categoriesForCurrentMode().contains(selectedCategory) {
            self.selectedCategory = nil
        }
        applyMode()
    }
}

extension LedgerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        previewTransactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LedgerTransactionCell.reuseIdentifier, for: indexPath) as? LedgerTransactionCell
        cell?.configure(with: previewTransactions[indexPath.row])
        return cell ?? UITableViewCell()
    }
}

extension LedgerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let transaction = previewTransactions[indexPath.row]
        let detailViewController = LedgerTransactionDetailViewController(transaction: transaction, transactionRepository: transactionRepository)
        detailViewController.onDelete = { [weak self] in
            self?.reloadData()
        }
        detailViewController.onUpdate = { [weak self] in
            self?.reloadData()
        }
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

private final class LedgerTransactionListViewController: ViewDayBaseViewController {
    var onUpdate: (() -> Void)?

    private let screenTitle: String
    private let transactionRepository: TransactionRepositoryProtocol
    private var transactions: [LedgerTransaction]
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateLabel = UILabel()

    init(
        title: String,
        transactions: [LedgerTransaction],
        transactionRepository: TransactionRepositoryProtocol
    ) {
        screenTitle = title
        self.transactions = transactions
        self.transactionRepository = transactionRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "全部账单"
        scrollView.removeFromSuperview()
        setupContent()
    }

    private func setupContent() {
        let titleLabel = UILabel()
        titleLabel.text = screenTitle
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = ViewDayTheme.primaryText

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LedgerTransactionCell.self, forCellReuseIdentifier: LedgerTransactionCell.reuseIdentifier)

        emptyStateLabel.text = "还没有账单"
        emptyStateLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        emptyStateLabel.textColor = ViewDayTheme.secondaryText
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.isHidden = !transactions.isEmpty
        tableView.isHidden = transactions.isEmpty

        view.addSubview(titleLabel)
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(20)
        }
    }
}

extension LedgerTransactionListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        transactions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LedgerTransactionCell.reuseIdentifier, for: indexPath) as? LedgerTransactionCell
        cell?.configure(with: transactions[indexPath.row])
        return cell ?? UITableViewCell()
    }
}

extension LedgerTransactionListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let transaction = transactions[indexPath.row]
        let detailViewController = LedgerTransactionDetailViewController(transaction: transaction, transactionRepository: transactionRepository)
        detailViewController.onDelete = { [weak self] in
            guard let self else { return }
            transactions.removeAll { $0.localId == transaction.localId }
            tableView.reloadData()
            emptyStateLabel.isHidden = !transactions.isEmpty
            tableView.isHidden = transactions.isEmpty
            onUpdate?()
        }
        detailViewController.onUpdate = { [weak self] in
            self?.onUpdate?()
        }
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}
