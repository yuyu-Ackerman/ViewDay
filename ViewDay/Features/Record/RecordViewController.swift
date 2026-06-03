import SnapKit
import PhotosUI
import UIKit

/// 记录页控制器。
/// 在同一页面内支持日记和账本两种记录模式，并统一处理附件、标签、位置和天气快照。
final class RecordViewController: ViewDayBaseViewController {
    private let diaryRepository: DiaryRepositoryProtocol
    private let transactionRepository: TransactionRepositoryProtocol
    private let attachmentRepository: AttachmentRepository
    private let tagRepository: TagRepository
    private let attachmentStorageService: AttachmentStorageService
    private let locationService: LocationServiceProtocol
    private let weatherService: WeatherSnapshotServiceProtocol
    private let audioRecorderService: AudioRecorderServiceProtocol

    private let pageTitleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let calendarButton = UIButton(type: .system)
    private let segmentedControl = UISegmentedControl(items: ["日记", "收支"])
    private let stackView = UIStackView()
    private let actionBar = UIStackView()
    private let draftButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let refreshControl = UIRefreshControl()

    private var selectedMood: MoodType = .calm
    private weak var diaryTextInputCard: RecordTextInputCardView?
    private weak var amountInputCard: RecordAmountInputCardView?
    private weak var categoryPickerCard: TransactionCategoryPickerCardView?
    private weak var transactionTextInputCard: RecordTextInputCardView?
    private weak var attachmentGridView: AttachmentActionGridView?
    private var selectedImages: [UIImage] = []
    private let selectedImageStripView = SelectedImageStripView()
    private var selectedAudioURL: URL?
    private var selectedTags: [Tag] = []
    private var selectedRecordDate = Date()
    private var recordDateWasManuallySelected = false
    private var recordDateRefreshTimer: Timer?
    private weak var presentedDatePicker: UIDatePicker?
    private var currentLocation: LocationSnapshot?
    private var currentWeather: WeatherSnapshot?
    private var locationRequestID = UUID()

    // MARK: - Lifecycle

    init(
        diaryRepository: DiaryRepositoryProtocol = DiaryRepository(),
        transactionRepository: TransactionRepositoryProtocol = TransactionRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository(),
        tagRepository: TagRepository = TagRepository(),
        attachmentStorageService: AttachmentStorageService = AttachmentStorageService(),
        locationService: LocationServiceProtocol = LocationService(),
        weatherService: WeatherSnapshotServiceProtocol = WeatherSnapshotService(),
        audioRecorderService: AudioRecorderServiceProtocol = AudioRecorderService()
    ) {
        self.diaryRepository = diaryRepository
        self.transactionRepository = transactionRepository
        self.attachmentRepository = attachmentRepository
        self.tagRepository = tagRepository
        self.attachmentStorageService = attachmentStorageService
        self.locationService = locationService
        self.weatherService = weatherService
        self.audioRecorderService = audioRecorderService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        setupKeyboardDismiss()
        setupRefreshInteractions()
        setupContent()
        selectedImageStripView.delegate = self
        restoreDraftIfAvailable()
        requestLocationAndWeather()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        startRecordDateRefreshTimer()
        refreshAutomaticRecordDate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        stopRecordDateRefreshTimer()
    }

    // MARK: - Setup

    private func setupContent() {
        pageTitleLabel.text = "记录"
        pageTitleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        pageTitleLabel.textColor = ViewDayTheme.primaryText

        subtitleLabel.text = "快速写下今天"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        subtitleLabel.textColor = ViewDayTheme.secondaryText

        calendarButton.backgroundColor = ViewDayTheme.controlBackground
        calendarButton.tintColor = ViewDayTheme.iconPrimary
        calendarButton.layer.cornerRadius = 12
        calendarButton.setImage(UIImage(systemName: "calendar", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        calendarButton.addTarget(self, action: #selector(calendarButtonTapped), for: .touchUpInside)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = ViewDayTheme.controlBackground
        segmentedControl.selectedSegmentTintColor = ViewDayTheme.cardBackground
        segmentedControl.setTitleTextAttributes([.foregroundColor: ViewDayTheme.secondaryText], for: .normal)
        segmentedControl.setTitleTextAttributes([.foregroundColor: ViewDayTheme.accent], for: .selected)
        segmentedControl.addTarget(self, action: #selector(modeDidChange), for: .valueChanged)

        stackView.axis = .vertical
        stackView.spacing = 14

        setupActionBar()

        contentView.addSubview(pageTitleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(calendarButton)
        contentView.addSubview(segmentedControl)
        contentView.addSubview(stackView)
        contentView.addSubview(actionBar)

        pageTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
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

        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(36)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        actionBar.snp.makeConstraints { make in
            make.top.equalTo(stackView.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(24)
            make.height.equalTo(52)
        }

        addDiaryModeViews()
    }

    private func setupActionBar() {
        actionBar.axis = .horizontal
        actionBar.spacing = 12
        actionBar.distribution = .fillEqually

        draftButton.setTitle("存草稿", for: .normal)
        draftButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        draftButton.setTitleColor(ViewDayTheme.primaryText, for: .normal)
        draftButton.backgroundColor = ViewDayTheme.cardBackground
        draftButton.layer.cornerRadius = 8
        draftButton.layer.borderWidth = 1
        draftButton.layer.borderColor = ViewDayTheme.border.cgColor
        draftButton.addTarget(self, action: #selector(draftButtonTapped), for: .touchUpInside)

        doneButton.setTitle("完成", for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        doneButton.setTitleColor(.black, for: .normal)
        doneButton.backgroundColor = ViewDayTheme.accent
        doneButton.layer.cornerRadius = 8
        doneButton.addTarget(self, action: #selector(doneButtonTapped), for: .touchUpInside)

        actionBar.addArrangedSubview(draftButton)
        actionBar.addArrangedSubview(doneButton)
    }

    private func setupKeyboardDismiss() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    private func setupRefreshInteractions() {
        refreshControl.tintColor = ViewDayTheme.accent
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        let swipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(refreshControlTriggered))
        swipeGesture.direction = .up
        swipeGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(swipeGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Mode Switching

    @objc private func modeDidChange() {
        clearStackView()
        selectedImages = []
        selectedAudioURL = nil
        selectedTags = []
        updateAttachmentStateViews()

        if segmentedControl.selectedSegmentIndex == 0 {
            subtitleLabel.text = "快速写下今天"
            addDiaryModeViews()
        } else {
            subtitleLabel.text = "快速记一笔收支"
            addTransactionModeViews()
        }
        updateActionBarForMode()
    }

    private func clearStackView() {
        diaryTextInputCard = nil
        amountInputCard = nil
        categoryPickerCard = nil
        transactionTextInputCard = nil
        attachmentGridView = nil
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func addDiaryModeViews() {
        let moodPickerView = MoodPickerView(selectedMood: selectedMood)
        moodPickerView.delegate = self

        let textInputCard = RecordTextInputCardView(title: "今天发生了什么？", placeholder: "写下一点今天发生的事...")
        diaryTextInputCard = textInputCard
        textInputCard.delegate = self
        textInputCard.configureMetadata(items: [
            ("clock", currentTimeText()),
            ("location", locationDisplayText()),
            ("sun.max", weatherDisplayText())
        ])

        let attachmentGridView = AttachmentActionGridView()
        attachmentGridView.delegate = self
        self.attachmentGridView = attachmentGridView

        stackView.addArrangedSubview(moodPickerView)
        stackView.addArrangedSubview(textInputCard)
        stackView.addArrangedSubview(attachmentGridView)
        stackView.addArrangedSubview(selectedImageStripView)
        updateAttachmentStateViews()
        updateActionBarForMode()
    }

    private func addTransactionModeViews() {
        let amountCard = RecordAmountInputCardView()
        amountCard.addTarget(self, action: #selector(transactionTypeDidChange(_:)), for: .valueChanged)
        amountInputCard = amountCard

        let categoryCard = TransactionCategoryPickerCardView(type: amountCard.transactionType)
        categoryCard.delegate = self
        categoryPickerCard = categoryCard

        let detailCard = RecordTextInputCardView(title: "账单内容", placeholder: "备注或描述，例如：和朋友吃火锅")
        transactionTextInputCard = detailCard
        detailCard.delegate = self
        detailCard.configureMetadata(items: [
            ("clock", currentTimeText()),
            ("location", locationDisplayText()),
            ("sun.max", weatherDisplayText())
        ])
        let attachmentGridView = AttachmentActionGridView()
        attachmentGridView.delegate = self
        self.attachmentGridView = attachmentGridView

        stackView.addArrangedSubview(amountCard)
        stackView.addArrangedSubview(categoryCard)
        stackView.addArrangedSubview(detailCard)
        stackView.addArrangedSubview(attachmentGridView)
        stackView.addArrangedSubview(selectedImageStripView)
        updateAttachmentStateViews()
        updateActionBarForMode()
    }

    private func updateActionBarForMode() {
        let isTransactionMode = segmentedControl.selectedSegmentIndex == 1
        // 账本流水不提供草稿入口，避免未完成金额参与后续账本编辑流程。
        draftButton.isHidden = isTransactionMode
    }

    // MARK: - Date Selection

    private func currentTimeText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(selectedRecordDate) ? "HH:mm" : "M月d日 HH:mm"
        return formatter.string(from: selectedRecordDate)
    }

    private func startRecordDateRefreshTimer() {
        stopRecordDateRefreshTimer()
        recordDateRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refreshAutomaticRecordDate()
        }
    }

    private func stopRecordDateRefreshTimer() {
        recordDateRefreshTimer?.invalidate()
        recordDateRefreshTimer = nil
    }

    private func refreshAutomaticRecordDate() {
        guard !recordDateWasManuallySelected else { return }
        selectedRecordDate = Date()
        refreshMetadataRows()
    }

    private func refreshAutomaticRecordDateBeforePersisting() {
        guard !recordDateWasManuallySelected else { return }
        selectedRecordDate = Date()
        refreshMetadataRows()
    }

    @objc private func calendarButtonTapped() {
        view.endEditing(true)

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = selectedRecordDate
        datePicker.maximumDate = Date()
        presentedDatePicker = datePicker

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.edges.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择记录时间"
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissDatePicker))
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(applyPickedRecordDate))
        present(navigationController, animated: true)
    }

    @objc private func dismissDatePicker() {
        presentedDatePicker = nil
        dismiss(animated: true)
    }

    @objc private func applyPickedRecordDate() {
        if let datePicker = presentedDatePicker {
            selectedRecordDate = datePicker.date
            recordDateWasManuallySelected = true
            refreshMetadataRows()
        }
        dismissDatePicker()
    }

    @objc private func draftButtonTapped() {
        saveCurrentMode(isDraft: true)
    }

    @objc private func doneButtonTapped() {
        saveCurrentMode(isDraft: false)
    }

    // MARK: - Persistence

    private func saveCurrentMode(isDraft: Bool) {
        view.endEditing(true)
        refreshAutomaticRecordDateBeforePersisting()
        guard selectedRecordDate <= Date() else {
            showResult(title: "不能选择未来时间", message: "记录时间不能晚于当前时间。")
            return
        }

        if audioRecorderService.isRecording {
            // 保存前先结束录音，确保附件路径已经稳定可写入仓储。
            selectedAudioURL = audioRecorderService.stopRecording()
            updateAttachmentStateViews()
        }

        if isDraft {
            do {
                try persistRecordDraft()
                showResult(title: "已存草稿", message: nil)
            } catch {
                showResult(title: "草稿保存失败", message: error.localizedDescription)
            }
            return
        }

        do {
            if segmentedControl.selectedSegmentIndex == 0 {
                try saveDiary(isDraft: isDraft)
            } else {
                try saveTransaction(isDraft: isDraft)
            }

            showResult(title: isDraft ? "已存草稿" : "已保存", message: nil)
            clearStoredDraft()
            clearInputsAfterSave()
        } catch RecordSaveError.emptyDiaryContent {
            showResult(title: "还没有内容", message: "写一点内容后再保存。")
        } catch RecordSaveError.invalidAmount {
            showResult(title: "金额不正确", message: "请输入有效金额。")
        } catch {
            showResult(title: "保存失败", message: error.localizedDescription)
        }
    }

    private func saveDiary(isDraft: Bool) throws {
        let content = diaryTextInputCard?.textValue ?? ""
        guard !content.isEmpty else {
            throw RecordSaveError.emptyDiaryContent
        }

        let now = Date()
        let diary = DiaryEntry(
            localId: UUID(),
            remoteId: nil,
            content: content,
            mood: selectedMood,
            entryDate: selectedRecordDate,
            location: currentLocation,
            weather: currentWeather,
            isFavorite: false,
            isDraft: isDraft,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .pendingCreate
        )

        let savedDiary = try diaryRepository.save(diary)
        // 附件和标签依赖保存后的日记 localId，因此先落日记主体再建立关联。
        try saveSelectedImages(ownerId: savedDiary.localId, ownerType: .diary)
        try saveSelectedAudio(ownerId: savedDiary.localId, ownerType: .diary)
        try tagRepository.replaceTags(forDiaryId: savedDiary.localId, with: selectedTags)
    }

    private func saveTransaction(isDraft: Bool) throws {
        guard
            let amountInputCard,
            let amount = amountInputCard.amount,
            NSDecimalNumber(decimal: amount).compare(NSDecimalNumber.zero) == .orderedDescending
        else {
            throw RecordSaveError.invalidAmount
        }

        let detailText = transactionTextInputCard?.textValue
        let sanitizedDetailText = detailText.flatMap { $0.isEmpty ? nil : $0 }
        let now = Date()
        let transactionType = amountInputCard.transactionType
        let transaction = LedgerTransaction(
            localId: UUID(),
            remoteId: nil,
            amount: amount,
            type: transactionType,
            category: categoryPickerCard?.selectedCategory ?? (transactionType == .expense ? .food : .salary),
            accountId: nil,
            note: sanitizedDetailText,
            detailText: sanitizedDetailText,
            transactionDate: selectedRecordDate,
            location: currentLocation,
            weather: currentWeather,
            isDraft: isDraft,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .pendingCreate
        )

        let savedTransaction = try transactionRepository.save(transaction)
        // 流水当前只支持图片附件，音频和标签保留给日记模式。
        try saveSelectedImages(ownerId: savedTransaction.localId, ownerType: .transaction)
    }

    private func clearInputsAfterSave() {
        if segmentedControl.selectedSegmentIndex == 0 {
            diaryTextInputCard?.clearText()
        } else {
            amountInputCard?.amountTextField.text = nil
            transactionTextInputCard?.clearText()
        }
        selectedImages = []
        selectedAudioURL = nil
        selectedTags = []
        selectedRecordDate = Date()
        recordDateWasManuallySelected = false
        updateAttachmentStateViews()
        refreshMetadataRows()
    }

    private func showResult(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "好", style: .default))
        present(alertController, animated: true)
    }

    private func updateAttachmentStateViews() {
        selectedImageStripView.configure(images: selectedImages)
        let audioCount = audioRecorderService.isRecording || selectedAudioURL != nil ? 1 : 0
        attachmentGridView?.configureBadges(
            imageCount: selectedImages.count,
            audioCount: audioCount,
            tagCount: selectedTags.count
        )
    }

    // MARK: - Location And Weather

    private func requestLocationAndWeather() {
        let requestID = UUID()
        locationRequestID = requestID

        locationService.requestCurrentLocation { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.locationRequestID == requestID else { return }

                switch result {
                case let .success(location):
                    self.currentLocation = location
                    self.refreshMetadataRows()
                    self.requestWeather(for: location)
                case let .failure(error):
                    if (error as? LocationServiceError) == .permissionDenied {
                        // 权限拒绝时才落到手动地点；普通定位抖动保留自动重试入口。
                        self.currentLocation = LocationSnapshot(
                            name: "手动填写地点",
                            city: nil,
                            district: nil,
                            address: nil,
                            latitude: nil,
                            longitude: nil,
                            isManuallyEdited: true
                        )
                        self.presentPermissionSettingsAlert(title: "无法定位", message: "请在系统设置中允许定位，或继续手动填写地点。")
                    }
                    self.refreshMetadataRows()
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }

    private func requestWeather(for location: LocationSnapshot, showsFailureAlert: Bool = false) {
        Task { [weak self] in
            guard let self else { return }

            do {
                let weather = try await weatherService.fetchWeather(for: location)
                await MainActor.run {
                    self.currentWeather = weather
                    self.refreshMetadataRows()
                    self.refreshControl.endRefreshing()
                }
            } catch {
                await MainActor.run {
                    if showsFailureAlert {
                        self.showResult(title: "天气获取失败", message: weatherFailureMessage(error))
                    }
                    self.refreshMetadataRows()
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }

    @objc private func refreshControlTriggered() {
        refreshCurrentRecordContext()
    }

    private func refreshCurrentRecordContext() {
        view.endEditing(true)
        recordDateWasManuallySelected = false
        selectedRecordDate = Date()
        currentLocation = nil
        currentWeather = nil
        refreshMetadataRows()
        requestLocationAndWeather()
    }

    private func refreshMetadataRows() {
        if segmentedControl.selectedSegmentIndex == 0 {
            diaryTextInputCard?.configureMetadata(items: [
                ("clock", currentTimeText()),
                ("location", locationDisplayText()),
                ("sun.max", weatherDisplayText())
            ])
        } else {
            transactionTextInputCard?.configureMetadata(items: [
                ("clock", currentTimeText()),
                ("location", locationDisplayText()),
                ("sun.max", weatherDisplayText())
            ])
        }
    }

    private func locationDisplayText() -> String {
        guard let currentLocation else { return "定位中" }
        return currentLocation.name ?? currentLocation.district ?? currentLocation.city ?? "可手动修改"
    }

    // MARK: - Manual Metadata

    @objc private func transactionTypeDidChange(_ sender: RecordAmountInputCardView) {
        categoryPickerCard?.updateType(sender.transactionType)
    }

    private func presentManualLocationEditor() {
        let alertController = UIAlertController(title: "修改地点", message: "可以手动填写这条记录的地点。", preferredStyle: .alert)
        alertController.addTextField { [weak self] textField in
            textField.placeholder = "例如：江边、公司、家"
            textField.text = self?.currentLocation?.name
        }
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "保存", style: .default) { [weak self, weak alertController] _ in
            let text = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return }
            self?.currentLocation = LocationSnapshot(
                name: text,
                city: self?.currentLocation?.city,
                district: self?.currentLocation?.district,
                address: self?.currentLocation?.address,
                latitude: self?.currentLocation?.latitude,
                longitude: self?.currentLocation?.longitude,
                isManuallyEdited: true
            )
            self?.refreshMetadataRows()
            if let location = self?.currentLocation {
                self?.requestWeather(for: location)
            }
        })
        present(alertController, animated: true)
    }

    private func presentWeatherOptions() {
        let alertController = UIAlertController(title: "天气", message: weatherDisplayText(), preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "自动刷新", style: .default) { [weak self] _ in
            self?.refreshWeatherIfPossible()
        })
        alertController.addAction(UIAlertAction(title: "手动填写", style: .default) { [weak self] _ in
            self?.presentManualWeatherEditor()
        })
        alertController.addAction(UIAlertAction(title: "清除天气", style: .destructive) { [weak self] _ in
            self?.currentWeather = nil
            self?.refreshMetadataRows()
        })
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alertController, animated: true)
    }

    private func refreshWeatherIfPossible() {
        guard let currentLocation else {
            showResult(title: "没有地点", message: "先填写地点后再刷新天气。")
            return
        }

        requestWeather(for: currentLocation, showsFailureAlert: true)
    }

    private func presentManualWeatherEditor() {
        ManualWeatherEditor.present(from: self, existingWeather: currentWeather) { [weak self] weather in
            self?.currentWeather = weather
            self?.refreshMetadataRows()
        }
    }

    private func weatherDisplayText() -> String {
        guard let currentWeather else { return "可手动填写天气" }
        if let temperature = currentWeather.temperature, let condition = currentWeather.condition {
            return "\(Int(temperature.rounded()))°C \(condition)"
        }
        return currentWeather.condition ?? "可手动填写天气"
    }

    // MARK: - Attachments

    private func presentImagePicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 9

        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        present(pickerViewController, animated: true)
    }

    private func saveSelectedImages(ownerId: UUID, ownerType: AttachmentOwnerType) throws {
        for (index, image) in selectedImages.enumerated() {
            let file = try attachmentStorageService.saveImage(image)
            let now = Date()
            let attachment = Attachment(
                localId: UUID(),
                remoteId: nil,
                ownerId: ownerId,
                ownerType: ownerType,
                type: .image,
                localFilePath: file.path,
                remoteURL: nil,
                fileName: file.fileName,
                mimeType: "image/jpeg",
                fileSize: file.fileSize,
                duration: nil,
                sortOrder: index,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil,
                syncStatus: .pendingCreate
            )
            try attachmentRepository.save(attachment)
        }
    }

    private func saveSelectedAudio(ownerId: UUID, ownerType: AttachmentOwnerType) throws {
        guard let selectedAudioURL else { return }

        let attributes = try? FileManager.default.attributesOfItem(atPath: selectedAudioURL.path)
        let fileSize = attributes?[.size] as? Int64
        let now = Date()
        let attachment = Attachment(
            localId: UUID(),
            remoteId: nil,
            ownerId: ownerId,
            ownerType: ownerType,
            type: .audio,
            localFilePath: selectedAudioURL.path,
            remoteURL: nil,
            fileName: selectedAudioURL.lastPathComponent,
            mimeType: "audio/mp4",
            fileSize: fileSize,
            duration: nil,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            syncStatus: .pendingCreate
        )
        try attachmentRepository.save(attachment)
    }

    private func toggleAudioRecording() {
        guard segmentedControl.selectedSegmentIndex == 0 else {
            showResult(title: "暂不支持", message: "第一版账单先支持图片和文字描述，语音先用于日记。")
            return
        }

        if audioRecorderService.isRecording {
            selectedAudioURL = audioRecorderService.stopRecording()
            updateAttachmentStateViews()
            return
        }

        audioRecorderService.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.presentPermissionSettingsAlert(title: "无法录音", message: "请在系统设置中允许麦克风权限。")
                return
            }

            do {
                self.selectedAudioURL = try self.audioRecorderService.startRecording()
                self.updateAttachmentStateViews()
            } catch {
                self.showResult(title: "录音失败", message: error.localizedDescription)
            }
        }
    }

    private func presentTagSelection() {
        guard segmentedControl.selectedSegmentIndex == 0 else {
            showResult(title: "暂不支持", message: "第一版标签先用于日记。")
            return
        }

        let tagSelectionViewController = TagSelectionViewController(selectedTags: selectedTags, tagRepository: tagRepository)
        tagSelectionViewController.onSave = { [weak self] tags in
            self?.selectedTags = tags
            self?.updateAttachmentStateViews()
        }
        present(UINavigationController(rootViewController: tagSelectionViewController), animated: true)
    }

    private func presentPermissionSettingsAlert(title: String, message: String) {
        PermissionSettingsPresenter.presentSettingsAlert(from: self, title: title, message: message)
    }
}

// MARK: - Public Mode Shortcuts

extension RecordViewController {
    func showTransactionMode() {
        loadViewIfNeeded()
        guard segmentedControl.selectedSegmentIndex != 1 else { return }
        segmentedControl.selectedSegmentIndex = 1
        modeDidChange()
    }

    func showDiaryMode() {
        loadViewIfNeeded()
        guard segmentedControl.selectedSegmentIndex != 0 else { return }
        segmentedControl.selectedSegmentIndex = 0
        modeDidChange()
    }

    private func persistRecordDraft() throws {
        let previousDraft = loadStoredDraft()
        // 草稿图片先另存为附件文件，再把路径写入 UserDefaults，避免大图数据直接塞进偏好设置。
        let imagePaths = try persistDraftImages(replacing: previousDraft?.imagePaths ?? [])
        let draft = RecordDraft(
            modeIndex: segmentedControl.selectedSegmentIndex,
            selectedMood: selectedMood.rawValue,
            diaryContent: diaryTextInputCard?.textValue,
            transactionAmount: amountInputCard?.amountTextField.text,
            transactionType: amountInputCard?.transactionType.rawValue,
            transactionCategory: categoryPickerCard?.selectedCategory.rawValue,
            transactionText: transactionTextInputCard?.textValue,
            selectedRecordDate: selectedRecordDate,
            recordDateWasManuallySelected: recordDateWasManuallySelected,
            imagePaths: imagePaths,
            audioPath: selectedAudioURL?.path,
            tagIds: selectedTags.map(\.localId)
        )
        let data = try JSONEncoder().encode(draft)
        UserDefaults.standard.set(data, forKey: RecordDraft.storageKey)
    }

    private func restoreDraftIfAvailable() {
        guard let draft = loadStoredDraft() else { return }

        selectedRecordDate = draft.selectedRecordDate
        recordDateWasManuallySelected = draft.recordDateWasManuallySelected ?? false
        refreshAutomaticRecordDate()
        if let mood = draft.selectedMood.flatMap(MoodType.init(rawValue:)) {
            selectedMood = mood
        }
        selectedImages = draft.imagePaths.compactMap { UIImage(contentsOfFile: $0) }
        selectedAudioURL = draft.audioPath.map(URL.init(fileURLWithPath:))
        selectedTags = restoreTags(ids: draft.tagIds)

        if draft.modeIndex == 1 {
            // 恢复时先重建对应模式的输入卡片，再把草稿字段回填到弱引用指向的组件。
            segmentedControl.selectedSegmentIndex = 1
            clearStackView()
            addTransactionModeViews()
            amountInputCard?.amountTextField.text = draft.transactionAmount
            if let type = draft.transactionType.flatMap(TransactionType.init(rawValue:)) {
                amountInputCard?.typeControl.selectedSegmentIndex = type == .expense ? 0 : 1
                let category = draft.transactionCategory.flatMap(TransactionCategory.init(rawValue:))
                    ?? TransactionCategory.available(for: type).first
                    ?? .other
                categoryPickerCard?.configure(type: type, selectedCategory: category)
            }
            transactionTextInputCard?.setText(draft.transactionText ?? "")
        } else {
            clearStackView()
            addDiaryModeViews()
            diaryTextInputCard?.setText(draft.diaryContent ?? "")
        }

        refreshMetadataRows()
        updateAttachmentStateViews()
        activeTextInputCard()?.textView.becomeFirstResponder()
    }

    private func activeTextInputCard() -> RecordTextInputCardView? {
        segmentedControl.selectedSegmentIndex == 0 ? diaryTextInputCard : transactionTextInputCard
    }

    private func persistDraftImages(replacing oldPaths: [String]) throws -> [String] {
        // 覆盖草稿时清理旧草稿图片，避免反复存草稿产生无主文件。
        oldPaths.forEach { try? FileManager.default.removeItem(atPath: $0) }
        return try selectedImages.map { image in
            try attachmentStorageService.saveImage(image).path
        }
    }

    private func restoreTags(ids: [UUID]) -> [Tag] {
        guard !ids.isEmpty else { return [] }
        let tags = (try? tagRepository.fetchAllTags()) ?? []
        return tags.filter { ids.contains($0.localId) }
    }

    private func loadStoredDraft() -> RecordDraft? {
        guard let data = UserDefaults.standard.data(forKey: RecordDraft.storageKey) else { return nil }
        return try? JSONDecoder().decode(RecordDraft.self, from: data)
    }

    private func clearStoredDraft() {
        let draft = loadStoredDraft()
        // 正式保存后删除草稿图片，真实附件已经在保存流程中重新写入仓储。
        draft?.imagePaths.forEach { try? FileManager.default.removeItem(atPath: $0) }
        UserDefaults.standard.removeObject(forKey: RecordDraft.storageKey)
    }
}

// MARK: - MoodPickerViewDelegate

extension RecordViewController: MoodPickerViewDelegate {
    func moodPickerView(_ view: MoodPickerView, didSelect mood: MoodType) {
        selectedMood = mood
    }
}

// MARK: - AttachmentActionGridViewDelegate

extension RecordViewController: AttachmentActionGridViewDelegate {
    func attachmentActionGridViewDidTapImages(_ view: AttachmentActionGridView) {
        presentImagePicker()
    }

    func attachmentActionGridViewDidTapLocation(_ view: AttachmentActionGridView) {
        presentManualLocationEditor()
    }

    func attachmentActionGridViewDidTapAudio(_ view: AttachmentActionGridView) {
        toggleAudioRecording()
    }

    func attachmentActionGridViewDidTapTags(_ view: AttachmentActionGridView) {
        presentTagSelection()
    }
}

// MARK: - PHPickerViewControllerDelegate

extension RecordViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else { return }

        selectedImages = []
        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var loadedImages: [UIImage] = []

        // PHPicker 回调来自后台线程，使用锁保护数组，并在全部完成后统一回到主线程刷新 UI。
        results.forEach { result in
            guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
            dispatchGroup.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage {
                    lock.lock()
                    loadedImages.append(image)
                    lock.unlock()
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            self?.selectedImages = loadedImages
            self?.updateAttachmentStateViews()
            self?.refreshMetadataRows()
        }
    }
}

// MARK: - SelectedImageStripViewDelegate

extension RecordViewController: SelectedImageStripViewDelegate {
    func selectedImageStripView(_ view: SelectedImageStripView, didRemoveImageAt index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        updateAttachmentStateViews()
        refreshMetadataRows()
    }
}

// MARK: - TransactionCategoryPickerCardViewDelegate

extension RecordViewController: TransactionCategoryPickerCardViewDelegate {
    func transactionCategoryPickerCardView(_ view: TransactionCategoryPickerCardView, didSelect category: TransactionCategory) {
    }
}

// MARK: - RecordTextInputCardViewDelegate

extension RecordViewController: RecordTextInputCardViewDelegate {
    func recordTextInputCardViewDidTapLocation(_ view: RecordTextInputCardView) {
        presentManualLocationEditor()
    }

    func recordTextInputCardViewDidTapWeather(_ view: RecordTextInputCardView) {
        presentManualWeatherEditor()
    }
}

/// 记录保存过程中的页面级校验错误。
private enum RecordSaveError: Error {
    case emptyDiaryContent
    case invalidAmount
}

/// 记录页本地草稿。
/// 使用轻量 Codable 结构存储输入状态，图片和音频仍以文件路径形式保存。
private struct RecordDraft: Codable {
    static let storageKey = "viewday.recordDraft"

    var modeIndex: Int
    var selectedMood: String?
    var diaryContent: String?
    var transactionAmount: String?
    var transactionType: String?
    var transactionCategory: String?
    var transactionText: String?
    var selectedRecordDate: Date
    var recordDateWasManuallySelected: Bool?
    var imagePaths: [String]
    var audioPath: String?
    var tagIds: [UUID]
}
