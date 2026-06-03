import SnapKit
import UIKit

/// 日记列表控制器。
/// 支持按筛选条件和搜索文本浏览日记，并跳转到详情或编辑页。
final class DiaryListViewController: UIViewController {
    private let diaryRepository: DiaryRepositoryProtocol
    private let attachmentRepository: AttachmentRepository
    private let tagRepository: TagRepository
    private let pageTitleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let calendarButton = UIButton(type: .system)
    private let searchBar = UISearchBar()
    private let filterBarView = DiaryFilterBarView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyStateLabel = UILabel()

    private var allDiaries: [DiaryEntry] = []
    private var visibleDiaries: [DiaryEntry] = []
    private var tagsByDiaryId: [UUID: [Tag]] = [:]
    private var imagePathsByDiaryId: [UUID: [String]] = [:]
    private var selectedFilter: DiaryFilter = .all
    private var selectedMood: MoodType?
    private var selectedDateFilter: Date?
    private weak var presentedDatePicker: UIDatePicker?

    init(
        diaryRepository: DiaryRepositoryProtocol = DiaryRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository(),
        tagRepository: TagRepository = TagRepository()
    ) {
        self.diaryRepository = diaryRepository
        self.attachmentRepository = attachmentRepository
        self.tagRepository = tagRepository
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ViewDayTheme.background
        navigationItem.title = nil
        setupHeader()
        setupSearchBar()
        setupFilterBar()
        setupTableView()
        setupEmptyState()
        updateDateFilterButton()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        reloadData()
        updateDateFilterButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupSearchBar() {
        searchBar.placeholder = "搜索日记、地点或心情"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.tintColor = ViewDayTheme.iconPrimary

        view.addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
    }

    private func setupHeader() {
        pageTitleLabel.text = "日记"
        pageTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        pageTitleLabel.textColor = ViewDayTheme.primaryText

        subtitleLabel.text = formattedTodayText()
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        subtitleLabel.textColor = ViewDayTheme.secondaryText

        calendarButton.backgroundColor = ViewDayTheme.controlBackground
        calendarButton.tintColor = ViewDayTheme.iconPrimary
        calendarButton.layer.cornerRadius = 12
        calendarButton.setImage(UIImage(systemName: "calendar", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        calendarButton.addTarget(self, action: #selector(dateFilterButtonTapped), for: .touchUpInside)

        view.addSubview(pageTitleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(calendarButton)

        pageTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(calendarButton.snp.leading).offset(-12)
        }

        calendarButton.snp.makeConstraints { make in
            make.centerY.equalTo(pageTitleLabel)
            make.trailing.equalToSuperview().inset(20)
            make.width.height.equalTo(40)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(pageTitleLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().inset(20)
            make.trailing.lessThanOrEqualTo(calendarButton.snp.leading).offset(-12)
        }
    }

    private func updateDateFilterButton() {
        let symbolName = selectedDateFilter == nil ? "calendar" : "xmark.circle"
        calendarButton.setImage(UIImage(systemName: symbolName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        calendarButton.tintColor = selectedDateFilter == nil ? ViewDayTheme.iconPrimary : ViewDayTheme.accent
    }

    private func setupFilterBar() {
        filterBarView.delegate = self

        view.addSubview(filterBarView)
        filterBarView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(36)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DiaryTimelineCell.self, forCellReuseIdentifier: DiaryTimelineCell.reuseIdentifier)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(filterBarView.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func setupEmptyState() {
        emptyStateLabel.text = "还没有日记"
        emptyStateLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        emptyStateLabel.textColor = ViewDayTheme.secondaryText
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.isHidden = true

        view.addSubview(emptyStateLabel)
        emptyStateLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(32)
        }
    }

    private func reloadData() {
        do {
            let diaries: [DiaryEntry]
            if let selectedDateFilter {
                diaries = try diaryRepository.fetchDiaries(on: selectedDateFilter, calendar: .current)
            } else {
                diaries = try diaryRepository.fetchRecentDiaries(limit: 80, searchText: nil)
            }
            allDiaries = diaries.filter { matchesSearch($0) }
            applyFilter()
        } catch {
            allDiaries = []
            visibleDiaries = []
            updateEmptyState()
            tableView.reloadData()
        }
    }

    private func matchesSearch(_ diary: DiaryEntry) -> Bool {
        guard let searchText = searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), !searchText.isEmpty else {
            return true
        }

        let values = [
            diary.content,
            diary.location?.name,
            diary.location?.city,
            diary.location?.district,
            moodTitle(diary.mood),
            diary.mood.rawValue
        ].compactMap { $0 }

        return values.contains { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func applyFilter() {
        switch selectedFilter {
        case .all:
            visibleDiaries = allDiaries.filter { !$0.isDraft }
        case .image:
            let ownerIds = (try? attachmentRepository.fetchOwnerIdsWithAttachments(ownerType: .diary, attachmentType: .image)) ?? []
            visibleDiaries = allDiaries.filter { ownerIds.contains($0.localId) }
        case .mood:
            if let selectedMood {
                visibleDiaries = allDiaries.filter { $0.mood == selectedMood }
            } else {
                visibleDiaries = allDiaries.filter { !$0.isDraft }
            }
        case .favorite:
            visibleDiaries = allDiaries.filter(\.isFavorite)
        }

        if let selectedDateFilter {
            visibleDiaries = visibleDiaries.filter { Calendar.current.isDate($0.entryDate, inSameDayAs: selectedDateFilter) }
        }

        updateEmptyState()
        reloadVisibleMetadata()
        tableView.reloadData()
    }

    private func reloadVisibleMetadata() {
        tagsByDiaryId = [:]
        imagePathsByDiaryId = [:]

        visibleDiaries.forEach { diary in
            tagsByDiaryId[diary.localId] = (try? tagRepository.fetchTags(forDiaryId: diary.localId)) ?? []
            let attachments = (try? attachmentRepository.fetchAttachments(ownerId: diary.localId, ownerType: .diary)) ?? []
            imagePathsByDiaryId[diary.localId] = attachments
                .filter { $0.type == .image }
                .map(\.localFilePath)
        }
    }

    private func updateEmptyState() {
        let isEmpty = visibleDiaries.isEmpty
        emptyStateLabel.isHidden = !isEmpty
        tableView.isHidden = isEmpty

        if isEmpty, let text = searchBar.text, !text.isEmpty {
            emptyStateLabel.text = "没有找到相关日记"
        } else if isEmpty, selectedDateFilter != nil {
            emptyStateLabel.text = "这一天还没有日记"
        } else if isEmpty, selectedFilter == .image {
            emptyStateLabel.text = "还没有图文日记"
        } else if isEmpty, selectedFilter == .mood, let selectedMood {
            emptyStateLabel.text = "还没有\(moodTitle(selectedMood))心情的日记"
        } else if isEmpty, selectedFilter == .favorite {
            emptyStateLabel.text = "还没有收藏日记"
        } else {
            emptyStateLabel.text = "还没有日记"
        }
    }

    private func dateSectionTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func formattedTodayText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: Date())
    }

    @objc private func dateFilterButtonTapped() {
        view.endEditing(true)
        if selectedDateFilter != nil {
            selectedDateFilter = nil
            reloadData()
            updateDateFilterButton()
            return
        }

        presentDatePicker()
    }

    private func presentDatePicker() {
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = selectedDateFilter ?? Date()
        datePicker.addTarget(self, action: #selector(dateFilterDateChanged(_:)), for: .valueChanged)
        presentedDatePicker = datePicker

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.edges.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择日记日期"
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissDatePicker))
        present(navigationController, animated: true)
    }

    @objc private func dismissDatePicker() {
        presentedDatePicker = nil
        dismiss(animated: true)
    }

    @objc private func dateFilterDateChanged(_ sender: UIDatePicker) {
        selectedDateFilter = sender.date
        dismiss(animated: true) { [weak self] in
            self?.presentedDatePicker = nil
            self?.reloadData()
            self?.updateDateFilterButton()
        }
    }
}

extension DiaryListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        groupedDiaries.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        groupedDiaries[section].items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DiaryTimelineCell.reuseIdentifier, for: indexPath) as? DiaryTimelineCell
        let diary = groupedDiaries[indexPath.section].items[indexPath.row]
        cell?.configure(
            with: diary,
            tags: tagsByDiaryId[diary.localId] ?? [],
            imagePaths: imagePathsByDiaryId[diary.localId] ?? []
        )
        cell?.onFavoriteToggle = { [weak self] in
            self?.toggleFavorite(for: diary)
        }
        return cell ?? UITableViewCell()
    }

    private var groupedDiaries: [(date: Date, items: [DiaryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleDiaries) { diary in
            calendar.startOfDay(for: diary.entryDate)
        }

        return grouped
            .map { (date: $0.key, items: $0.value.sorted { $0.entryDate > $1.entryDate }) }
            .sorted { $0.date > $1.date }
    }

    private func toggleFavorite(for diary: DiaryEntry) {
        do {
            try diaryRepository.updateFavorite(id: diary.localId, isFavorite: !diary.isFavorite)
            reloadData()
        } catch {
            let alertController = UIAlertController(title: "更新失败", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "好", style: .default))
            present(alertController, animated: true)
        }
    }
}

extension DiaryListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        34
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = ViewDayTheme.background

        let label = UILabel()
        label.text = dateSectionTitle(for: groupedDiaries[section].date)
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = ViewDayTheme.primaryText

        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(4)
        }

        return container
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let diary = groupedDiaries[indexPath.section].items[indexPath.row]
        let detailViewController = DiaryDetailViewController(diary: diary, diaryRepository: diaryRepository)
        detailViewController.onDelete = { [weak self] in
            self?.reloadData()
        }
        detailViewController.onUpdate = { [weak self] in
            self?.reloadData()
        }
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

extension DiaryListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        reloadData()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension DiaryListViewController: DiaryFilterBarViewDelegate {
    func diaryFilterBarView(_ view: DiaryFilterBarView, didSelect filter: DiaryFilter) {
        selectedFilter = filter
        if filter == .mood {
            presentMoodFilter()
        } else {
            selectedMood = nil
            applyFilter()
        }
    }

    private func presentMoodFilter() {
        let alertController = UIAlertController(title: "选择心情", message: nil, preferredStyle: .actionSheet)
        MoodType.allCases.forEach { mood in
            alertController.addAction(UIAlertAction(title: moodTitle(mood), style: .default) { [weak self] _ in
                self?.selectedMood = mood
                self?.applyFilter()
            })
        }
        alertController.addAction(UIAlertAction(title: "全部心情", style: .default) { [weak self] _ in
            self?.selectedMood = nil
            self?.applyFilter()
        })
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.applyFilter()
        })
        present(alertController, animated: true)
    }

    private func moodTitle(_ mood: MoodType) -> String {
        mood.displayTitle
    }
}
