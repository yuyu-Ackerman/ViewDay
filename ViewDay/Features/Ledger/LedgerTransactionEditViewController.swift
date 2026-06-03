import PhotosUI
import SnapKit
import UIKit

/// 流水编辑控制器。
/// 用于修改已保存流水的金额、类型、分类、备注和发生时间。
final class LedgerTransactionEditViewController: ViewDayBaseViewController {
    var onSave: (() -> Void)?

    private var transaction: LedgerTransaction
    private let transactionRepository: TransactionRepositoryProtocol
    private let attachmentRepository: AttachmentRepository
    private let attachmentStorageService: AttachmentStorageService
    private let weatherService: WeatherSnapshotServiceProtocol
    private let amountCard = RecordAmountInputCardView()
    private let categoryCard: TransactionCategoryPickerCardView
    private let textInputCard = RecordTextInputCardView(title: "账单内容", placeholder: "备注或描述")
    private let attachmentGridView = AttachmentActionGridView()
    private let selectedImageStripView = SelectedImageStripView()
    private let selectedImageCountLabel = UILabel()
    private var selectedDate: Date
    private weak var presentedDatePicker: UIDatePicker?
    private var currentLocation: LocationSnapshot?
    private var currentWeather: WeatherSnapshot?
    private var selectedImages: [UIImage] = []
    private var imagesDidChange = false

    init(
        transaction: LedgerTransaction,
        transactionRepository: TransactionRepositoryProtocol = TransactionRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository(),
        attachmentStorageService: AttachmentStorageService = AttachmentStorageService(),
        weatherService: WeatherSnapshotServiceProtocol = WeatherSnapshotService()
    ) {
        self.transaction = transaction
        self.transactionRepository = transactionRepository
        self.attachmentRepository = attachmentRepository
        self.attachmentStorageService = attachmentStorageService
        self.weatherService = weatherService
        selectedDate = transaction.transactionDate
        currentLocation = transaction.location
        currentWeather = transaction.weather
        categoryCard = TransactionCategoryPickerCardView(type: transaction.type)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑账单"
        configureNavigationItems()
        loadAttachments()
        setupContent()
        configureInitialValues()
    }

    private func configureNavigationItems() {
        var items = [
            UIBarButtonItem(image: UIImage(systemName: "cloud.sun"), style: .plain, target: self, action: #selector(weatherButtonTapped)),
            UIBarButtonItem(image: UIImage(systemName: "calendar"), style: .plain, target: self, action: #selector(calendarButtonTapped))
        ]

        if transaction.isDraft {
            items.insert(UIBarButtonItem(title: "存草稿", style: .plain, target: self, action: #selector(saveDraftButtonTapped)), at: 0)
            items.insert(UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(completeButtonTapped)), at: 0)
        } else {
            items.insert(UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveButtonTapped)), at: 0)
        }

        navigationItem.rightBarButtonItems = items
    }

    private func setupContent() {
        amountCard.addTarget(self, action: #selector(transactionTypeDidChange(_:)), for: .valueChanged)
        categoryCard.delegate = self
        textInputCard.delegate = self
        attachmentGridView.delegate = self
        selectedImageStripView.delegate = self
        setupStatusLabels()
        textInputCard.configureMetadata(items: [
            ("clock", formattedTime(selectedDate)),
            ("location", locationText()),
            ("sun.max", weatherText())
        ])

        contentView.addSubview(amountCard)
        contentView.addSubview(categoryCard)
        contentView.addSubview(textInputCard)
        contentView.addSubview(attachmentGridView)
        contentView.addSubview(selectedImageStripView)
        contentView.addSubview(selectedImageCountLabel)

        amountCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        categoryCard.snp.makeConstraints { make in
            make.top.equalTo(amountCard.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        textInputCard.snp.makeConstraints { make in
            make.top.equalTo(categoryCard.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        attachmentGridView.snp.makeConstraints { make in
            make.top.equalTo(textInputCard.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        selectedImageStripView.snp.makeConstraints { make in
            make.top.equalTo(attachmentGridView.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        selectedImageCountLabel.snp.makeConstraints { make in
            make.top.equalTo(selectedImageStripView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(24)
        }
    }

    private func configureInitialValues() {
        amountCard.amountTextField.text = NSDecimalNumber(decimal: transaction.amount).stringValue
        amountCard.typeControl.selectedSegmentIndex = transaction.type == .expense ? 0 : 1
        categoryCard.configure(type: transaction.type, selectedCategory: transaction.category)

        if let text = transaction.detailText ?? transaction.note, !text.isEmpty {
            textInputCard.setText(text)
        }
        refreshMetadataRows()
        updateSelectedImageCount()
    }

    private func setupStatusLabels() {
        selectedImageCountLabel.font = .systemFont(ofSize: 13, weight: .medium)
        selectedImageCountLabel.textColor = ViewDayTheme.secondaryText
        selectedImageCountLabel.textAlignment = .center
    }

    private func loadAttachments() {
        let attachments = (try? attachmentRepository.fetchAttachments(ownerId: transaction.localId, ownerType: .transaction)) ?? []
        selectedImages = attachments
            .filter { $0.type == .image }
            .compactMap { UIImage(contentsOfFile: $0.localFilePath) }
    }

    @objc private func transactionTypeDidChange(_ sender: RecordAmountInputCardView) {
        categoryCard.updateType(sender.transactionType)
    }

    @objc private func saveButtonTapped() {
        saveEditedTransaction(isDraft: transaction.isDraft)
    }

    @objc private func saveDraftButtonTapped() {
        saveEditedTransaction(isDraft: true)
    }

    @objc private func completeButtonTapped() {
        saveEditedTransaction(isDraft: false)
    }

    private func saveEditedTransaction(isDraft: Bool) {
        guard
            let amount = amountCard.amount,
            NSDecimalNumber(decimal: amount).compare(NSDecimalNumber.zero) == .orderedDescending
        else {
            showAlert(title: "金额不正确", message: "请输入有效金额。")
            return
        }

        transaction.amount = amount
        transaction.type = amountCard.transactionType
        transaction.category = categoryCard.selectedCategory
        transaction.transactionDate = selectedDate
        transaction.location = currentLocation
        transaction.weather = currentWeather
        let text = textInputCard.textValue
        transaction.note = text.isEmpty ? nil : text
        transaction.detailText = text.isEmpty ? nil : text
        transaction.isDraft = isDraft

        do {
            try transactionRepository.updateTransaction(transaction)
            try saveEditedImagesIfNeeded()
            onSave?()
            navigationController?.popViewController(animated: true)
        } catch {
            showAlert(title: "保存失败", message: error.localizedDescription)
        }
    }

    @objc private func calendarButtonTapped() {
        view.endEditing(true)

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .inline
        datePicker.date = selectedDate
        presentedDatePicker = datePicker

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.edges.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择账单时间"
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(dismissDatePicker))
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(applyPickedDate))
        present(navigationController, animated: true)
    }

    @objc private func dismissDatePicker() {
        presentedDatePicker = nil
        dismiss(animated: true)
    }

    @objc private func applyPickedDate() {
        if let datePicker = presentedDatePicker {
            selectedDate = datePicker.date
            refreshMetadataRows()
        }
        dismissDatePicker()
    }

    @objc private func weatherButtonTapped() {
        presentWeatherOptions()
    }

    private func presentManualLocationEditor() {
        let alertController = UIAlertController(title: "修改地点", message: "可以手动填写这笔账单的地点。", preferredStyle: .alert)
        alertController.addTextField { [weak self] textField in
            textField.placeholder = "例如：公司、江边、餐厅"
            textField.text = self?.currentLocation?.name
        }
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "保存", style: .default) { [weak self, weak alertController] _ in
            guard let self else { return }
            let text = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !text.isEmpty else { return }

            self.currentLocation = LocationSnapshot(
                name: text,
                city: self.currentLocation?.city,
                district: self.currentLocation?.district,
                address: self.currentLocation?.address,
                latitude: self.currentLocation?.latitude,
                longitude: self.currentLocation?.longitude,
                isManuallyEdited: true
            )
            self.currentWeather = nil
            self.refreshMetadataRows()
        })
        present(alertController, animated: true)
    }

    private func refreshWeatherIfPossible() {
        guard let currentLocation else {
            showAlert(title: "没有地点", message: "先填写地点后再刷新天气。")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let weather = try await weatherService.fetchWeather(for: currentLocation)
                await MainActor.run {
                    self.currentWeather = weather
                    self.refreshMetadataRows()
                }
            } catch {
                await MainActor.run {
                    self.showAlert(title: "天气获取失败", message: weatherFailureMessage(error))
                    self.refreshMetadataRows()
                }
            }
        }
    }

    private func presentWeatherOptions() {
        let alertController = UIAlertController(title: "天气", message: weatherText(), preferredStyle: .actionSheet)
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

    private func presentManualWeatherEditor() {
        ManualWeatherEditor.present(from: self, existingWeather: currentWeather) { [weak self] weather in
            self?.currentWeather = weather
            self?.refreshMetadataRows()
        }
    }

    private func presentImagePicker() {
        let remainingSlots = 9 - selectedImages.count
        guard remainingSlots > 0 else {
            showAlert(title: "图片已达上限", message: "第一版最多保留 9 张图片。")
            return
        }

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = remainingSlots

        let pickerViewController = PHPickerViewController(configuration: configuration)
        pickerViewController.delegate = self
        present(pickerViewController, animated: true)
    }

    private func saveEditedImagesIfNeeded() throws {
        guard imagesDidChange else { return }

        try attachmentRepository.softDeleteAttachments(ownerId: transaction.localId, ownerType: .transaction, attachmentType: .image)
        for (index, image) in selectedImages.enumerated() {
            let file = try attachmentStorageService.saveImage(image)
            let now = Date()
            try attachmentRepository.save(Attachment(
                localId: UUID(),
                remoteId: nil,
                ownerId: transaction.localId,
                ownerType: .transaction,
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
            ))
        }
    }

    private func updateSelectedImageCount() {
        selectedImageCountLabel.text = selectedImages.isEmpty ? "未选择图片" : "已选择 \(selectedImages.count) 张图片"
        selectedImageStripView.configure(images: selectedImages)
    }

    private func refreshMetadataRows() {
        textInputCard.configureMetadata(items: [
            ("clock", formattedTime(selectedDate)),
            ("location", locationText()),
            ("sun.max", weatherText())
        ])
    }

    private func showAlert(title: String, message: String?) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "好", style: .default))
        present(alertController, animated: true)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter.string(from: date)
    }

    private func locationText() -> String {
        currentLocation?.name ?? currentLocation?.district ?? currentLocation?.city ?? "未记录地点"
    }

    private func weatherText() -> String {
        guard let weather = currentWeather else { return "可手动填写天气" }
        if let temperature = weather.temperature, let condition = weather.condition {
            return "\(Int(temperature.rounded()))°C \(condition)"
        }
        return weather.condition ?? "可手动填写天气"
    }
}

extension LedgerTransactionEditViewController: TransactionCategoryPickerCardViewDelegate {
    func transactionCategoryPickerCardView(_ view: TransactionCategoryPickerCardView, didSelect category: TransactionCategory) {
    }
}

extension LedgerTransactionEditViewController: AttachmentActionGridViewDelegate {
    func attachmentActionGridViewDidTapImages(_ view: AttachmentActionGridView) {
        presentImagePicker()
    }

    func attachmentActionGridViewDidTapLocation(_ view: AttachmentActionGridView) {
        presentManualLocationEditor()
    }

    func attachmentActionGridViewDidTapAudio(_ view: AttachmentActionGridView) {
        showAlert(title: "暂不支持", message: "第一版账单只支持图片附件。")
    }

    func attachmentActionGridViewDidTapTags(_ view: AttachmentActionGridView) {
        showAlert(title: "暂不支持", message: "第一版标签先用于日记。")
    }
}

extension LedgerTransactionEditViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        let dispatchGroup = DispatchGroup()
        let lock = NSLock()
        var loadedImages: [UIImage] = []

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
            guard let self else { return }
            self.selectedImages.append(contentsOf: loadedImages)
            self.imagesDidChange = true
            self.updateSelectedImageCount()
        }
    }
}

extension LedgerTransactionEditViewController: SelectedImageStripViewDelegate {
    func selectedImageStripView(_ view: SelectedImageStripView, didRemoveImageAt index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        imagesDidChange = true
        updateSelectedImageCount()
    }
}

extension LedgerTransactionEditViewController: RecordTextInputCardViewDelegate {
    func recordTextInputCardViewDidTapLocation(_ view: RecordTextInputCardView) {
        presentManualLocationEditor()
    }

    func recordTextInputCardViewDidTapWeather(_ view: RecordTextInputCardView) {
        presentManualWeatherEditor()
    }
}
