import SnapKit
import UIKit

/// 日记详情控制器。
/// 展示单篇日记的正文、元信息、附件和标签，并提供编辑、收藏和删除入口。
final class DiaryDetailViewController: ViewDayBaseViewController {
    /// 删除成功后通知来源列表刷新。
    var onDelete: (() -> Void)?
    /// 收藏、编辑等内容变化后通知来源页面同步状态。
    var onUpdate: (() -> Void)?

    /// 当前详情页展示的日记。
    /// 编辑返回后会重新从仓储读取，避免继续展示旧快照。
    private var diary: DiaryEntry
    private let diaryRepository: DiaryRepositoryProtocol
    private let attachmentRepository: AttachmentRepository
    private let tagRepository: TagRepository
    private let imageGridView = AttachmentImageGridView()
    private let audioPlayerView = AudioAttachmentPlayerView()
    private var favoriteButtonItem: UIBarButtonItem?

    init(
        diary: DiaryEntry,
        diaryRepository: DiaryRepositoryProtocol = DiaryRepository(),
        attachmentRepository: AttachmentRepository = AttachmentRepository(),
        tagRepository: TagRepository = TagRepository()
    ) {
        self.diary = diary
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
        title = "日记详情"
        configureNavigationItems()
        imageGridView.delegate = self
        setupContent()
    }

    /// 配置详情页操作按钮。
    /// 未来时间的日记不允许编辑，只保留删除和收藏，避免用户继续修改未到达日期的内容。
    private func configureNavigationItems() {
        let deleteButtonItem = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteButtonTapped))
        let favoriteButtonItem = UIBarButtonItem(image: UIImage(systemName: diary.isFavorite ? "star.fill" : "star"), style: .plain, target: self, action: #selector(favoriteButtonTapped))
        self.favoriteButtonItem = favoriteButtonItem

        var items = [deleteButtonItem, favoriteButtonItem]
        if !isFutureDiary {
            items.append(UIBarButtonItem(title: "编辑", style: .plain, target: self, action: #selector(editButtonTapped)))
        }
        navigationItem.rightBarButtonItems = items
        updateFavoriteButtonAppearance()
    }

    /// 构建详情内容。
    ///
    /// 附件区域按“图片网格 -> 音频播放器”的顺序追加，只有存在附件时才扩展滚动内容底部。
    private func setupContent() {
        let headerCard = InfoCardView(title: formattedDate(diary.entryDate))
        headerCard.addRow(title: "时间", value: formattedTime(diary.entryDate))
        headerCard.addRow(title: "心情", value: "\(diary.mood.displayEmoji) \(diary.mood.displayTitle)", valueColor: ViewDayTheme.accent)
        headerCard.addRow(title: "地点", value: locationText(diary.location))
        headerCard.addRow(title: "天气", value: weatherText(diary.weather))
        headerCard.addRow(title: "标签", value: tagText())

        let contentCard = HomeSummaryCardView(title: "内容")
        contentCard.configure(
            subtitle: diary.isDraft ? "草稿" : nil,
            body: diary.content,
            accessory: diary.isFavorite ? "已收藏" : nil,
            bodyNumberOfLines: 0
        )

        let attachments = fetchAttachments()
        let imagePaths = attachments.filter { $0.type == .image }.map(\.localFilePath)
        let audioPath = attachments.first(where: { $0.type == .audio })?.localFilePath

        contentView.addSubview(headerCard)
        contentView.addSubview(contentCard)

        headerCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        contentCard.snp.makeConstraints { make in
            make.top.equalTo(headerCard.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        if imagePaths.isEmpty, audioPath == nil {
            contentCard.snp.makeConstraints { make in
                make.bottom.equalToSuperview().inset(24)
            }
        } else {
            var previousView: UIView = contentCard

            if !imagePaths.isEmpty {
                contentView.addSubview(imageGridView)
                imageGridView.configure(imagePaths: imagePaths)
                imageGridView.snp.makeConstraints { make in
                    make.top.equalTo(previousView.snp.bottom).offset(14)
                    make.leading.trailing.equalToSuperview().inset(20)
                }
                previousView = imageGridView
            }

            if audioPath != nil {
                contentView.addSubview(audioPlayerView)
                audioPlayerView.configure(audioPath: audioPath)
                audioPlayerView.snp.makeConstraints { make in
                    make.top.equalTo(previousView.snp.bottom).offset(14)
                    make.leading.trailing.equalToSuperview().inset(20)
                }
                previousView = audioPlayerView
            }

            previousView.snp.makeConstraints { make in
                make.bottom.equalToSuperview().inset(24)
            }
        }
    }

    /// 读取日记附件。
    /// 详情页将读取失败视为空附件，避免单个附件异常阻塞正文查看。
    private func fetchAttachments() -> [Attachment] {
        (try? attachmentRepository.fetchAttachments(ownerId: diary.localId, ownerType: .diary)) ?? []
    }

    @objc private func deleteButtonTapped() {
        let alertController = UIAlertController(title: "删除日记？", message: "删除后不会影响账单。", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            self?.deleteDiary()
        })
        present(alertController, animated: true)
    }

    /// 执行软删除。
    /// 仓储会负责清理附件和标签关系，详情页只处理成功后的导航和回调。
    private func deleteDiary() {
        do {
            try diaryRepository.softDeleteDiary(id: diary.localId)
            onDelete?()
            navigationController?.popViewController(animated: true)
        } catch {
            let alertController = UIAlertController(title: "删除失败", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "好", style: .default))
            present(alertController, animated: true)
        }
    }

    @objc private func favoriteButtonTapped() {
        do {
            let nextValue = !diary.isFavorite
            try diaryRepository.updateFavorite(id: diary.localId, isFavorite: nextValue)
            diary.isFavorite = nextValue
            favoriteButtonItem?.image = UIImage(systemName: nextValue ? "star.fill" : "star")
            updateFavoriteButtonAppearance()
            onUpdate?()
        } catch {
            let alertController = UIAlertController(title: "更新失败", message: error.localizedDescription, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "好", style: .default))
            present(alertController, animated: true)
        }
    }

    @objc private func editButtonTapped() {
        guard !isFutureDiary else {
            showFutureEditAlert()
            return
        }

        let editViewController = DiaryEditViewController(diary: diary, diaryRepository: diaryRepository)
        editViewController.onSave = { [weak self] in
            self?.reloadDiary()
            self?.onUpdate?()
        }
        navigationController?.pushViewController(editViewController, animated: true)
    }

    /// 编辑返回后重建详情内容。
    /// 直接移除并重建子视图，比逐项 diff 更简单，也能同步附件、标签和收藏按钮状态。
    private func reloadDiary() {
        do {
            guard let updatedDiary = try diaryRepository.fetchDiary(id: diary.localId) else { return }
            diary = updatedDiary
            contentView.subviews.forEach { $0.removeFromSuperview() }
            setupContent()
            configureNavigationItems()
        } catch {
            onUpdate?()
        }
    }

    private func updateFavoriteButtonAppearance() {
        favoriteButtonItem?.tintColor = diary.isFavorite ? ViewDayTheme.accent : ViewDayTheme.iconPrimary
    }

    /// 是否为未来时间的日记。
    /// 当前产品规则禁止编辑未来日记，但仍允许用户删除错误创建的记录。
    private var isFutureDiary: Bool {
        diary.entryDate > Date()
    }

    private func showFutureEditAlert() {
        let alertController = UIAlertController(title: "不能编辑未来日记", message: "这篇日记的记录时间还没到。", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "好", style: .default))
        present(alertController, animated: true)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func locationText(_ location: LocationSnapshot?) -> String {
        "📍 \(location?.name ?? location?.district ?? location?.city ?? "未记录地点")"
    }

    private func weatherText(_ weather: WeatherSnapshot?) -> String {
        guard let weather else { return "未记录天气" }
        if let temperature = weather.temperature, let condition = weather.condition {
            return "\(weatherIcon(for: condition)) \(Int(temperature.rounded()))°C \(condition)"
        }
        guard let condition = weather.condition else { return "未记录天气" }
        return "\(weatherIcon(for: condition)) \(condition)"
    }

    private func tagText() -> String {
        let tags = (try? tagRepository.fetchTags(forDiaryId: diary.localId)) ?? []
        return tags.isEmpty ? "未添加标签" : tags.map { "#\($0.name)" }.joined(separator: "、")
    }

    /// 根据中文天气描述选择轻量图标。
    /// 天气来源可能是自动接口或手动填写，因此这里只做包含关系匹配。
    private func weatherIcon(for condition: String) -> String {
        if condition.contains("雨") { return "🌧️" }
        if condition.contains("雪") { return "❄️" }
        if condition.contains("雷") { return "⛈️" }
        if condition.contains("云") || condition.contains("阴") { return "☁️" }
        if condition.contains("雾") || condition.contains("霾") { return "🌫️" }
        return "☀️"
    }
}

extension DiaryDetailViewController: AttachmentImageGridViewDelegate {
    func attachmentImageGridView(_ view: AttachmentImageGridView, didSelectImageAt index: Int, images: [UIImage]) {
        let previewViewController = UINavigationController(rootViewController: ImageGalleryPreviewViewController(images: images, initialIndex: index))
        present(previewViewController, animated: true)
    }
}
