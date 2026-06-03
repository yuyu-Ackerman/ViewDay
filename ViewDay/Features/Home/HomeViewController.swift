import SnapKit
import ObjectiveC
import UIKit

/// 首页控制器。
/// 展示所选日期的位置天气、日记摘要和收支摘要，并提供跳转到记录页或账本页的入口。
final class HomeViewController: ViewDayBaseViewController {
    private let dashboardRepository: DashboardRepository
    private let attachmentRepository: AttachmentRepository
    private let locationService: LocationServiceProtocol
    private let weatherService: WeatherSnapshotServiceProtocol
    private let headerCardView = UIView()
    private let locationLabel = UILabel()
    private let dateLabel = UILabel()
    private let weatherLabel = UILabel()
    private let calendarButton = UIButton(type: .system)
    private let dateStripView: HomeDateStripView
    private let diaryCard = HomeDiaryListCardView()
    private let financeStripView = HomeFinanceStripView()
    private let addButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()

    private var selectedDate: Date
    private var currentOverview: DailyOverview?
    private var weatherTask: Task<Void, Never>?
    private var currentHeaderLocation: LocationSnapshot?
    private var currentHeaderWeather: WeatherSnapshot?

    // MARK: - Lifecycle

    init(
        dashboardRepository: DashboardRepository = DashboardRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository(),
        locationService: LocationServiceProtocol = LocationService(),
        weatherService: WeatherSnapshotServiceProtocol = WeatherSnapshotService(),
        selectedDate: Date = Date()
    ) {
        self.dashboardRepository = dashboardRepository
        self.attachmentRepository = attachmentRepository
        self.locationService = locationService
        self.weatherService = weatherService
        self.selectedDate = selectedDate
        dateStripView = HomeDateStripView(selectedDate: selectedDate)
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        weatherTask?.cancel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        dateStripView.delegate = self
        diaryCard.delegate = self
        setupRefreshControl()
        setupContent()
        setupInteractions()
        reloadOverview()
        refreshCurrentLocationAndWeather()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reloadOverview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Setup

    private func setupContent() {
        setupHeader()
        setupAddButton()

        contentView.addSubview(headerCardView)
        contentView.addSubview(dateStripView)
        contentView.addSubview(diaryCard)
        contentView.addSubview(financeStripView)

        headerCardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        dateStripView.snp.makeConstraints { make in
            make.top.equalTo(headerCardView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        diaryCard.snp.makeConstraints { make in
            make.top.equalTo(dateStripView.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        financeStripView.snp.makeConstraints { make in
            make.top.equalTo(diaryCard.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(28)
        }
    }

    private func setupInteractions() {
        financeStripView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(financeStripTapped)))

        diaryCard.accessibilityTraits.insert(.button)
        diaryCard.accessibilityLabel = "查看当日日记"
        financeStripView.accessibilityTraits.insert(.button)
        financeStripView.accessibilityLabel = "查看当日收支"
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = ViewDayTheme.accent
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }

    private func setupHeader() {
        headerCardView.backgroundColor = .clear
        headerCardView.layer.cornerRadius = 0
        headerCardView.layer.borderWidth = 0

        locationLabel.font = .systemFont(ofSize: 27, weight: .bold)
        locationLabel.textColor = ViewDayTheme.primaryText
        locationLabel.adjustsFontSizeToFitWidth = true
        locationLabel.minimumScaleFactor = 0.7
        locationLabel.numberOfLines = 1

        dateLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        dateLabel.textColor = ViewDayTheme.secondaryText

        weatherLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        weatherLabel.textColor = ViewDayTheme.primaryText
        weatherLabel.backgroundColor = ViewDayTheme.controlBackground
        weatherLabel.layer.cornerRadius = 14
        weatherLabel.clipsToBounds = true
        weatherLabel.textAlignment = .center

        calendarButton.backgroundColor = ViewDayTheme.controlBackground
        calendarButton.tintColor = ViewDayTheme.iconPrimary
        calendarButton.layer.cornerRadius = 12
        calendarButton.setImage(UIImage(systemName: "calendar", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        calendarButton.addTarget(self, action: #selector(calendarButtonTapped), for: .touchUpInside)

        headerCardView.addSubview(locationLabel)
        headerCardView.addSubview(dateLabel)
        headerCardView.addSubview(weatherLabel)
        headerCardView.addSubview(calendarButton)

        weatherLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(dateLabel.snp.bottom).offset(8)
            make.height.equalTo(28)
            make.width.greaterThanOrEqualTo(88)
            make.bottom.equalToSuperview()
        }

        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(locationLabel.snp.bottom).offset(6)
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualTo(calendarButton.snp.leading).offset(-12)
        }

        locationLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.lessThanOrEqualTo(calendarButton.snp.leading).offset(-12)
        }

        calendarButton.snp.makeConstraints { make in
            make.top.equalTo(locationLabel).offset(2)
            make.trailing.equalToSuperview()
            make.width.height.equalTo(40)
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

    // MARK: - Data Loading

    private func reloadOverview() {
        dateLabel.text = formattedDate(selectedDate)
        dateStripView.configure(around: selectedDate, selectedDate: selectedDate)

        do {
            let overview = try dashboardRepository.dailyOverview(for: selectedDate)
            currentOverview = overview
            apply(overview)
        } catch {
            currentOverview = nil
            applyEmptyState()
        }
    }

    private func apply(_ overview: DailyOverview) {
        // 自动刷新到的实时位置天气优先展示；没有实时数据时回退到当天记录中保存的快照。
        locationLabel.text = locationText(from: currentHeaderLocation ?? overview.location)
        weatherLabel.text = weatherText(from: currentHeaderWeather ?? overview.weather)

        diaryCard.configure(diaries: overview.diaries, imagePathsByDiaryId: imagePathsByDiaryId(for: overview.diaries))

        financeStripView.configure(
            income: overview.todayIncome,
            expense: overview.todayExpense,
            balance: overview.todayBalance,
            latest: latestTransactionText(overview.latestTransaction)
        )
    }

    private func applyEmptyState() {
        locationLabel.text = locationText(from: currentHeaderLocation)
        weatherLabel.text = weatherText(from: currentHeaderWeather)
        diaryCard.configure(diaries: [])
        financeStripView.configure(income: .zero, expense: .zero, balance: .zero, latest: nil)
    }

    private func refreshCurrentLocationAndWeather() {
        weatherTask?.cancel()
        locationLabel.text = "定位中"
        weatherLabel.text = "天气获取中"

        locationService.requestCurrentLocation { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case let .success(location):
                    self.currentHeaderLocation = location
                    self.currentHeaderWeather = nil
                    self.locationLabel.text = self.locationText(from: location)
                    self.requestWeather(for: location)
                case .failure:
                    self.currentHeaderLocation = nil
                    self.currentHeaderWeather = nil
                    self.locationLabel.text = self.locationText(from: self.currentOverview?.location)
                    self.weatherLabel.text = self.weatherText(from: self.currentOverview?.weather)
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }

    private func requestWeather(for location: LocationSnapshot) {
        weatherTask?.cancel()
        weatherTask = Task { [weak self] in
            guard let self else { return }

            do {
                let weather = try await weatherService.fetchWeather(for: location)
                await MainActor.run {
                    self.currentHeaderWeather = weather
                    self.weatherLabel.text = self.weatherText(from: weather)
                    self.refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run {
                    self.currentHeaderWeather = nil
                    self.weatherLabel.text = self.weatherText(from: self.currentOverview?.weather)
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }

    // MARK: - Formatting

    private func imagePathsByDiaryId(for diaries: [DiaryEntry]) -> [UUID: [String]] {
        var pathsByDiaryId: [UUID: [String]] = [:]

        diaries.forEach { diary in
            let attachments = (try? attachmentRepository.fetchAttachments(ownerId: diary.localId, ownerType: .diary)) ?? []
            let imagePaths = attachments
                .filter { $0.type == .image }
                .map(\.localFilePath)
            pathsByDiaryId[diary.localId] = imagePaths
        }

        return pathsByDiaryId
    }

    private func locationText(from location: LocationSnapshot?) -> String {
        guard let location else { return "当前位置" }

        if let city = location.city, let district = location.district {
            return "\(city) \(shortenedLocationName(district))"
        }

        if let city = location.city {
            return city
        }

        if let name = location.name {
            return shortenedLocationName(name)
        }

        return "当前位置"
    }

    private func shortenedLocationName(_ name: String) -> String {
        // 首页标题空间有限，优先保留行政区或地点名称的第一段。
        let separators = CharacterSet(charactersIn: ",，-")
        let firstPart = name.components(separatedBy: separators).first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = firstPart?.isEmpty == false ? firstPart ?? name : name
        return candidate.count > 14 ? "\(candidate.prefix(14))..." : candidate
    }

    private func weatherText(from weather: WeatherSnapshot?) -> String {
        guard let weather else { return "天气待获取" }

        let temperatureText: String
        if let temperature = weather.temperature {
            temperatureText = "\(Int(temperature.rounded()))°C"
        } else {
            temperatureText = "--°C"
        }

        return "\(temperatureText) \(weather.condition ?? "")".trimmingCharacters(in: .whitespaces)
    }

    private func latestTransactionText(_ transaction: LedgerTransaction?) -> String? {
        guard let transaction else { return nil }
        let prefix = transaction.type == .income ? "+" : "-"
        return "\(categoryText(transaction.category)) \(prefix)\(formatCurrency(transaction.amount))"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
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
        case .food:
            return "餐饮"
        case .transport:
            return "交通"
        case .shopping:
            return "购物"
        case .entertainment:
            return "娱乐"
        case .home:
            return "居家"
        case .medical:
            return "医疗"
        case .salary:
            return "工资"
        case .partTime:
            return "兼职"
        case .gift:
            return "红包"
        case .investment:
            return "理财"
        case .other:
            return "其他"
        }
    }

    // MARK: - Actions

    @objc private func calendarButtonTapped() {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = selectedDate

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.edges.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择日期"
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissPresentedController))
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(applyPickedDate))
        // UIBarButtonItem target/action 无法直接携带 datePicker，这里把 picker 绑定到承载控制器。
        objc_setAssociatedObject(viewController, &AssociatedKeys.datePickerKey, datePicker, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        present(navigationController, animated: true)
    }

    @objc private func refreshControlTriggered() {
        reloadOverview()
        refreshCurrentLocationAndWeather()
    }

    @objc private func dismissPresentedController() {
        dismiss(animated: true)
    }

    @objc private func applyPickedDate() {
        guard
            let navigationController = presentedViewController as? UINavigationController,
            let viewController = navigationController.topViewController,
            let datePicker = objc_getAssociatedObject(viewController, &AssociatedKeys.datePickerKey) as? UIDatePicker
        else {
            dismiss(animated: true)
            return
        }

        selectedDate = datePicker.date
        dismiss(animated: true) { [weak self] in
            self?.reloadOverview()
        }
    }

    @objc private func addButtonTapped() {
        guard
            let tabBarController,
            let viewControllers = tabBarController.viewControllers,
            viewControllers.indices.contains(2)
        else {
            return
        }

        tabBarController.selectedIndex = 2
        if let navigationController = viewControllers[2] as? UINavigationController,
           let recordViewController = navigationController.viewControllers.first as? RecordViewController {
            recordViewController.showDiaryMode()
        }
    }

    private func openDiaryDetail(_ diary: DiaryEntry) {
        let detailViewController = DiaryDetailViewController(diary: diary)
        detailViewController.onDelete = { [weak self] in
            self?.reloadOverview()
        }
        detailViewController.onUpdate = { [weak self] in
            self?.reloadOverview()
        }
        navigationController?.pushViewController(detailViewController, animated: true)
    }

    @objc private func financeStripTapped() {
        openLedgerForSelectedDate()
    }

    private func openLedgerForSelectedDate() {
        guard
            let tabBarController,
            var viewControllers = tabBarController.viewControllers,
            viewControllers.indices.contains(3)
        else {
            return
        }

        let ledgerViewController = LedgerViewController(selectedMonth: selectedDate, selectedDateFilter: selectedDate)
        let navigationController = MainTabBarController.makeNavigationController(
            rootViewController: ledgerViewController,
            title: "账本",
            symbolName: "wallet.pass"
        )
        viewControllers[3] = navigationController
        tabBarController.viewControllers = viewControllers
        tabBarController.selectedIndex = 3
    }
}

// MARK: - HomeDateStripViewDelegate

extension HomeViewController: HomeDateStripViewDelegate {
    func homeDateStripView(_ view: HomeDateStripView, didSelect date: Date) {
        selectedDate = date
        reloadOverview()
    }
}

// MARK: - HomeDiaryListCardViewDelegate

extension HomeViewController: HomeDiaryListCardViewDelegate {
    func homeDiaryListCardView(_ view: HomeDiaryListCardView, didSelect diary: DiaryEntry) {
        openDiaryDetail(diary)
    }
}

private enum AssociatedKeys {
    static var datePickerKey: UInt8 = 0
}
