import PhotosUI
import SnapKit
import UIKit

/// 日记编辑控制器。
/// 用于修改已保存日记的正文、情绪、收藏状态和基础元信息。
final class DiaryEditViewController: ViewDayBaseViewController {
    var onSave: (() -> Void)?

    private var diary: DiaryEntry
    private let diaryRepository: DiaryRepositoryProtocol
    private let attachmentRepository: AttachmentRepository
    private let tagRepository: TagRepository
    private let attachmentStorageService: AttachmentStorageService
    private let weatherService: WeatherSnapshotServiceProtocol
    private let audioRecorderService: AudioRecorderServiceProtocol
    private let moodPickerView: MoodPickerView
    private let textInputCard = RecordTextInputCardView(title: "日记内容", placeholder: "写下一点今天发生的事")
    private let attachmentGridView = AttachmentActionGridView()
    private let selectedImageStripView = SelectedImageStripView()
    private let selectedImageCountLabel = UILabel()
    private let audioStatusLabel = UILabel()
    private let selectedTagsLabel = UILabel()
    private var selectedMood: MoodType
    private var selectedDate: Date
    private weak var presentedDatePicker: UIDatePicker?
    private var currentLocation: LocationSnapshot?
    private var currentWeather: WeatherSnapshot?
    private var selectedImages: [UIImage] = []
    private var imagesDidChange = false
    private var existingAudioAttachment: Attachment?
    private var selectedAudioURL: URL?
    private var selectedTags: [Tag] = []

    init(
        diary: DiaryEntry,
        diaryRepository: DiaryRepositoryProtocol = DiaryRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository(),
        tagRepository: TagRepository = TagRepository(),
        attachmentStorageService: AttachmentStorageService = AttachmentStorageService(),
        weatherService: WeatherSnapshotServiceProtocol = WeatherSnapshotService(),
        audioRecorderService: AudioRecorderServiceProtocol = AudioRecorderService()
    ) {
        self.diary = diary
        self.diaryRepository = diaryRepository
        self.attachmentRepository = attachmentRepository
        self.tagRepository = tagRepository
        self.attachmentStorageService = attachmentStorageService
        self.weatherService = weatherService
        self.audioRecorderService = audioRecorderService
        selectedMood = diary.mood
        selectedDate = diary.entryDate
        currentLocation = diary.location
        currentWeather = diary.weather
        moodPickerView = MoodPickerView(selectedMood: diary.mood)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "编辑日记"
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

        if diary.isDraft {
            items.insert(UIBarButtonItem(title: "存草稿", style: .plain, target: self, action: #selector(saveDraftButtonTapped)), at: 0)
            items.insert(UIBarButtonItem(title: "完成", style: .done, target: self, action: #selector(completeButtonTapped)), at: 0)
        } else {
            items.insert(UIBarButtonItem(title: "保存", style: .done, target: self, action: #selector(saveButtonTapped)), at: 0)
        }

        navigationItem.rightBarButtonItems = items
    }

    private func setupContent() {
        moodPickerView.delegate = self
        textInputCard.delegate = self
        attachmentGridView.delegate = self
        selectedImageStripView.delegate = self
        setupStatusLabels()
        textInputCard.configureMetadata(items: [
            ("clock", formattedTime(selectedDate)),
            ("location", locationText()),
            ("sun.max", weatherText())
        ])

        contentView.addSubview(moodPickerView)
        contentView.addSubview(textInputCard)
        contentView.addSubview(attachmentGridView)
        contentView.addSubview(selectedImageStripView)
        contentView.addSubview(selectedImageCountLabel)
        contentView.addSubview(audioStatusLabel)
        contentView.addSubview(selectedTagsLabel)

        moodPickerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        textInputCard.snp.makeConstraints { make in
            make.top.equalTo(moodPickerView.snp.bottom).offset(14)
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
        }

        audioStatusLabel.snp.makeConstraints { make in
            make.top.equalTo(selectedImageCountLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        selectedTagsLabel.snp.makeConstraints { make in
            make.top.equalTo(audioStatusLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(24)
        }
    }

    private func configureInitialValues() {
        textInputCard.setText(diary.content)
        refreshMetadataRows()
        updateSelectedImageCount()
        updateAudioStatus()
        updateSelectedTags()
    }

    private func setupStatusLabels() {
        selectedImageCountLabel.font = .systemFont(ofSize: 13, weight: .medium)
        selectedImageCountLabel.textColor = ViewDayTheme.secondaryText
        selectedImageCountLabel.textAlignment = .center

        audioStatusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        audioStatusLabel.textColor = ViewDayTheme.secondaryText
        audioStatusLabel.textAlignment = .center

        selectedTagsLabel.font = .systemFont(ofSize: 13, weight: .medium)
        selectedTagsLabel.textColor = ViewDayTheme.secondaryText
        selectedTagsLabel.textAlignment = .center
        selectedTagsLabel.numberOfLines = 2
    }

    private func loadAttachments() {
        let attachments = (try? attachmentRepository.fetchAttachments(ownerId: diary.localId, ownerType: .diary)) ?? []
        selectedImages = attachments
            .filter { $0.type == .image }
            .compactMap { UIImage(contentsOfFile: $0.localFilePath) }
        existingAudioAttachment = attachments.first { $0.type == .audio }
        selectedTags = (try? tagRepository.fetchTags(forDiaryId: diary.localId)) ?? []
    }

    @objc private func saveButtonTapped() {
        saveEditedDiary(isDraft: diary.isDraft)
    }

    @objc private func saveDraftButtonTapped() {
        saveEditedDiary(isDraft: true)
    }

    @objc private func completeButtonTapped() {
        saveEditedDiary(isDraft: false)
    }

    private func saveEditedDiary(isDraft: Bool) {
        view.endEditing(true)
        guard selectedDate <= Date() else {
            showAlert(title: "不能编辑未来日记", message: "记录时间不能晚于当前时间。")
            return
        }

        if audioRecorderService.isRecording {
            selectedAudioURL = audioRecorderService.stopRecording()
            updateAudioStatus()
        }

        let content = textInputCard.textValue

        guard !content.isEmpty else {
            showAlert(title: "还没有内容", message: "写一点内容后再保存。")
            return
        }

        diary.content = content
        diary.mood = selectedMood
        diary.entryDate = selectedDate
        diary.location = currentLocation
        diary.weather = currentWeather
        diary.isDraft = isDraft

        do {
            try diaryRepository.updateDiary(diary)
            try saveEditedImagesIfNeeded()
            try saveEditedAudioIfNeeded()
            try tagRepository.replaceTags(forDiaryId: diary.localId, with: selectedTags)
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
        datePicker.maximumDate = Date()
        presentedDatePicker = datePicker

        let viewController = UIViewController()
        viewController.view.backgroundColor = ViewDayTheme.background
        viewController.view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.edges.equalTo(viewController.view.safeAreaLayoutGuide).inset(16)
        }

        let navigationController = UINavigationController(rootViewController: viewController)
        viewController.title = "选择日记时间"
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
        let alertController = UIAlertController(title: "修改地点", message: "可以手动填写这篇日记的地点。", preferredStyle: .alert)
        alertController.addTextField { [weak self] textField in
            textField.placeholder = "例如：江边、公司、家"
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

    private func toggleAudioRecording() {
        if audioRecorderService.isRecording {
            selectedAudioURL = audioRecorderService.stopRecording()
            updateAudioStatus()
            return
        }

        audioRecorderService.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                PermissionSettingsPresenter.presentSettingsAlert(from: self, title: "无法录音", message: "请在系统设置中允许麦克风权限。")
                return
            }

            do {
                self.selectedAudioURL = try self.audioRecorderService.startRecording()
                self.updateAudioStatus()
            } catch {
                self.showAlert(title: "录音失败", message: error.localizedDescription)
            }
        }
    }

    private func saveEditedImagesIfNeeded() throws {
        guard imagesDidChange else { return }

        try attachmentRepository.softDeleteAttachments(ownerId: diary.localId, ownerType: .diary, attachmentType: .image)
        for (index, image) in selectedImages.enumerated() {
            let file = try attachmentStorageService.saveImage(image)
            let now = Date()
            try attachmentRepository.save(Attachment(
                localId: UUID(),
                remoteId: nil,
                ownerId: diary.localId,
                ownerType: .diary,
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

    private func saveEditedAudioIfNeeded() throws {
        guard let selectedAudioURL else { return }

        try attachmentRepository.softDeleteAttachments(ownerId: diary.localId, ownerType: .diary, attachmentType: .audio)
        let attributes = try? FileManager.default.attributesOfItem(atPath: selectedAudioURL.path)
        let fileSize = attributes?[.size] as? Int64
        let now = Date()
        try attachmentRepository.save(Attachment(
            localId: UUID(),
            remoteId: nil,
            ownerId: diary.localId,
            ownerType: .diary,
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
        ))
    }

    private func updateSelectedImageCount() {
        selectedImageCountLabel.text = selectedImages.isEmpty ? "未选择图片" : "已选择 \(selectedImages.count) 张图片"
        selectedImageStripView.configure(images: selectedImages)
    }

    private func updateAudioStatus() {
        if audioRecorderService.isRecording {
            audioStatusLabel.text = "正在录音，点击语音停止"
        } else if selectedAudioURL != nil {
            audioStatusLabel.text = "已录制新语音"
        } else if existingAudioAttachment != nil {
            audioStatusLabel.text = "已保留原语音"
        } else {
            audioStatusLabel.text = "未录制语音"
        }
    }

    private func updateSelectedTags() {
        selectedTagsLabel.text = selectedTags.isEmpty ? "未选择标签" : "标签：" + selectedTags.map(\.name).joined(separator: "、")
    }

    private func presentTagSelection() {
        let tagSelectionViewController = TagSelectionViewController(selectedTags: selectedTags, tagRepository: tagRepository)
        tagSelectionViewController.onSave = { [weak self] tags in
            self?.selectedTags = tags
            self?.updateSelectedTags()
        }
        present(UINavigationController(rootViewController: tagSelectionViewController), animated: true)
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

extension DiaryEditViewController: MoodPickerViewDelegate {
    func moodPickerView(_ view: MoodPickerView, didSelect mood: MoodType) {
        selectedMood = mood
    }
}

extension DiaryEditViewController: AttachmentActionGridViewDelegate {
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

extension DiaryEditViewController: PHPickerViewControllerDelegate {
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

extension DiaryEditViewController: SelectedImageStripViewDelegate {
    func selectedImageStripView(_ view: SelectedImageStripView, didRemoveImageAt index: Int) {
        guard selectedImages.indices.contains(index) else { return }
        selectedImages.remove(at: index)
        imagesDidChange = true
        updateSelectedImageCount()
    }
}

extension DiaryEditViewController: RecordTextInputCardViewDelegate {
    func recordTextInputCardViewDidTapLocation(_ view: RecordTextInputCardView) {
        presentManualLocationEditor()
    }

    func recordTextInputCardViewDidTapWeather(_ view: RecordTextInputCardView) {
        presentManualWeatherEditor()
    }
}
