import SnapKit
import UIKit

/// 首页日记卡片回调。
protocol HomeDiaryListCardViewDelegate: AnyObject {
    func homeDiaryListCardView(_ view: HomeDiaryListCardView, didSelect diary: DiaryEntry)
}

/// 首页日记列表卡片。
/// 展示当天日记摘要和关联图片缩略图。
final class HomeDiaryListCardView: UIView {
    weak var delegate: HomeDiaryListCardViewDelegate?

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        diaries: [DiaryEntry],
        imagePathsByDiaryId: [UUID: [String]] = [:],
        tagsByDiaryId: [UUID: [Tag]] = [:],
        //trailingText: String = "查看详情 >"
    ) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

       // countLabel.text = trailingText

        guard !diaries.isEmpty else {
            stackView.addArrangedSubview(EmptyDiaryView())
            return
        }

        diaries.forEach { diary in
            let row = DiarySummaryRow(
                diary: diary,
                imagePaths: imagePathsByDiaryId[diary.localId] ?? [],
                tags: tagsByDiaryId[diary.localId] ?? []
            )
            row.onTap = { [weak self] in
                guard let self else { return }
                self.delegate?.homeDiaryListCardView(self, didSelect: diary)
            }
            stackView.addArrangedSubview(row)
        }
    }

    private func setup() {
        backgroundColor = ViewDayTheme.elevatedCardBackground
        layer.cornerRadius = 10
        layer.borderColor = ViewDayTheme.border.cgColor
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.045
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)
        isUserInteractionEnabled = true

        titleLabel.text = "今日日记"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        countLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        countLabel.textColor = ViewDayTheme.secondaryText
        countLabel.textAlignment = .right

        stackView.axis = .vertical
        stackView.spacing = 10

        addSubview(titleLabel)
        addSubview(countLabel)
        addSubview(stackView)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(countLabel.snp.leading).offset(-12)
        }

        countLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(titleLabel)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
    }
}

private final class DiarySummaryRow: UIView {
    var onTap: (() -> Void)?

    private let previewContainer = UIView()
    private let thumbnailImageView = UIImageView()
    private let imageCountLabel = UILabel()
    private let timeLabel = UILabel()
    private let moodLabel = PaddingLabel()
    private let weatherLabel = UILabel()
    private let bodyLabel = UILabel()
    private let locationLabel = UILabel()
    private let tagsStackView = UIStackView()
    private var previewWidthConstraint: Constraint?
    private var previewHeightConstraint: Constraint?

    init(diary: DiaryEntry, imagePaths: [String], tags: [Tag]) {
        super.init(frame: .zero)
        setup()
        configure(diary, imagePaths: imagePaths, tags: tags)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rowTapped)))
        isUserInteractionEnabled = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 0
        layer.borderWidth = 1
        layer.borderColor = UIColor.clear.cgColor

        previewContainer.clipsToBounds = true
        previewContainer.layer.cornerRadius = 8
        previewContainer.backgroundColor = ViewDayTheme.cardBackground
        previewContainer.layer.borderWidth = 1
        previewContainer.layer.borderColor = ViewDayTheme.border.cgColor

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true

        imageCountLabel.font = .systemFont(ofSize: 11, weight: .bold)
        imageCountLabel.textColor = .white
        imageCountLabel.textAlignment = .center
        imageCountLabel.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        imageCountLabel.layer.cornerRadius = 10
        imageCountLabel.clipsToBounds = true
        imageCountLabel.isHidden = true

        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = ViewDayTheme.secondaryText

        moodLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        moodLabel.textColor = ViewDayTheme.accent
        moodLabel.backgroundColor = .clear
        moodLabel.layer.cornerRadius = 0
        moodLabel.clipsToBounds = true

        weatherLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        weatherLabel.textColor = ViewDayTheme.secondaryText
        weatherLabel.textAlignment = .right
        weatherLabel.numberOfLines = 1

        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = ViewDayTheme.primaryText
        bodyLabel.numberOfLines = 2

        locationLabel.font = .systemFont(ofSize: 13, weight: .medium)
        locationLabel.textColor = ViewDayTheme.secondaryText
        locationLabel.numberOfLines = 1

        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 6
        tagsStackView.alignment = .leading

        addSubview(previewContainer)
        previewContainer.addSubview(thumbnailImageView)
        previewContainer.addSubview(imageCountLabel)
        addSubview(timeLabel)
        addSubview(moodLabel)
        addSubview(weatherLabel)
        addSubview(bodyLabel)
        addSubview(locationLabel)
        addSubview(tagsStackView)

        previewContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(12)
            make.top.equalToSuperview().inset(12)
            previewWidthConstraint = make.width.equalTo(88).constraint
            previewHeightConstraint = make.height.equalTo(88).constraint
        }

        thumbnailImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        imageCountLabel.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(5)
            make.height.equalTo(20)
            make.width.greaterThanOrEqualTo(28)
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(12)
            make.leading.equalToSuperview().inset(12)
        }

        moodLabel.snp.makeConstraints { make in
            make.leading.equalTo(timeLabel.snp.trailing).offset(8)
            make.centerY.equalTo(timeLabel)
            make.trailing.lessThanOrEqualTo(weatherLabel.snp.leading).offset(-10)
        }

        weatherLabel.snp.makeConstraints { make in
            make.centerY.equalTo(timeLabel)
            make.trailing.lessThanOrEqualTo(previewContainer.snp.leading).offset(-12)
        }

        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(8)
            make.leading.equalTo(timeLabel)
            make.trailing.lessThanOrEqualTo(previewContainer.snp.leading).offset(-12)
        }

        locationLabel.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(8)
            make.leading.equalTo(timeLabel)
            make.trailing.lessThanOrEqualTo(previewContainer.snp.leading).offset(-12)
        }

        tagsStackView.snp.makeConstraints { make in
            make.top.equalTo(locationLabel.snp.bottom).offset(8)
            make.leading.equalTo(timeLabel)
            make.trailing.lessThanOrEqualTo(previewContainer.snp.leading).offset(-12)
            make.bottom.equalToSuperview().inset(12)
        }

//        snp.makeConstraints { make in
//            make.height.greaterThanOrEqualTo(128)
//        }
    }

    private func configure(_ diary: DiaryEntry, imagePaths: [String], tags: [Tag]) {
        timeLabel.text = timeText(diary.entryDate)
        moodLabel.text = moodText(diary.mood)
        weatherLabel.text = weatherText(diary.weather)
        weatherLabel.isHidden = weatherLabel.text?.isEmpty != false
        bodyLabel.text = diary.content.isEmpty ? "未填写正文" : diary.content
        let locationText = diary.location?.name ?? diary.location?.district ?? diary.location?.city
        locationLabel.text = locationText.map { "📍 \($0)" }
        locationLabel.isHidden = locationText?.isEmpty != false
        configureTags(tags)

        if let image = imagePaths.compactMap({ UIImage(contentsOfFile: $0) }).first {
            thumbnailImageView.image = image
            previewContainer.isHidden = false
            previewWidthConstraint?.update(offset: 88)
            previewHeightConstraint?.update(offset: 88)
            imageCountLabel.isHidden = imagePaths.count <= 1
            imageCountLabel.text = imagePaths.count > 1 ? "+\(imagePaths.count - 1)" : nil
        } else {
            thumbnailImageView.image = nil
            previewContainer.isHidden = true
            previewWidthConstraint?.update(offset: 0)
            previewHeightConstraint?.update(offset: 0)
            imageCountLabel.isHidden = true
        }
    }

    private func configureTags(_ tags: [Tag]) {
        tagsStackView.arrangedSubviews.forEach { view in
            tagsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        tagsStackView.isHidden = tags.isEmpty

        tags.prefix(3).forEach { tag in
            let label = PaddingLabel()
            label.text = "# \(tag.name)"
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.textColor = ViewDayTheme.secondaryText
            label.backgroundColor = ViewDayTheme.background
            label.layer.cornerRadius = 11
            label.clipsToBounds = true
            tagsStackView.addArrangedSubview(label)
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func moodText(_ mood: MoodType) -> String {
        mood.displayTitle
    }

    private func weatherText(_ weather: WeatherSnapshot?) -> String {
        guard let weather else { return "" }
        if let temperature = weather.temperature, let condition = weather.condition {
            return "\(weatherIcon(for: condition)) \(Int(temperature.rounded()))°C \(condition)"
        }
        if let temperature = weather.temperature {
            return "☀️ \(Int(temperature.rounded()))°C"
        }
        guard let condition = weather.condition else { return "" }
        return "\(weatherIcon(for: condition)) \(condition)"
    }

    private func weatherIcon(for condition: String) -> String {
        if condition.contains("雨") { return "🌧️" }
        if condition.contains("雪") { return "❄️" }
        if condition.contains("雷") { return "⛈️" }
        if condition.contains("云") || condition.contains("阴") { return "☁️" }
        if condition.contains("雾") || condition.contains("霾") { return "🌫️" }
        return "☀️"
    }

    @objc private func rowTapped() {
        onTap?()
    }
}

private final class EmptyDiaryView: UIView {
    // private let subtitleLabel = UILabel()
    private let bodyLabel = UILabel()
    // private let accessoryLabel = UILabel()

    init() {
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
//        subtitleLabel.text = "还没有记录"
//        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
//        subtitleLabel.textColor = ViewDayTheme.secondaryText

        bodyLabel.text = "还没有记录"
        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = ViewDayTheme.primaryText
        bodyLabel.numberOfLines = 2

//        accessoryLabel.text = "去记录"
//        accessoryLabel.font = .systemFont(ofSize: 13, weight: .medium)
//        accessoryLabel.textColor = ViewDayTheme.secondaryText

       // addSubview(subtitleLabel)
        addSubview(bodyLabel)
        // addSubview(accessoryLabel)

//        subtitleLabel.snp.makeConstraints { make in
//            make.top.leading.trailing.equalToSuperview()
//        }

        bodyLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

//        accessoryLabel.snp.makeConstraints { make in
//            make.top.equalTo(bodyLabel.snp.bottom).offset(12)
//            make.leading.trailing.bottom.equalToSuperview()
//        }
    }
}

private final class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + contentInsets.left + contentInsets.right, height: size.height + contentInsets.top + contentInsets.bottom)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}
