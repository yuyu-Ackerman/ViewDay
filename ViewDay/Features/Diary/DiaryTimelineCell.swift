import SnapKit
import UIKit

/// 日记时间线列表单元格。
/// 展示日记摘要、情绪、地点天气和附件提示。
final class DiaryTimelineCell: UITableViewCell {
    static let reuseIdentifier = "DiaryTimelineCell"

    var onFavoriteToggle: (() -> Void)?

    private let timelineLineView = UIView()
    private let markerView = UIView()
    private let cardView = UIView()
    private let timeLabel = UILabel()
    private let moodLabel = PaddingLabel()
    private let weatherLabel = UILabel()
    private let contentLabel = UILabel()
    private let imageSummaryView = DiaryImageSummaryView()
    private let locationLabel = UILabel()
    private let tagsStackView = UIStackView()
    private let favoriteButton = UIButton(type: .system)
    private var imageHeightConstraint: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(with diary: DiaryEntry, tags: [Tag] = [], imagePaths: [String] = []) {
        timeLabel.text = timeText(diary.entryDate)
        moodLabel.text = "\(diary.mood.displayEmoji)  \(diary.isDraft ? "草稿 · " : "")\(diary.mood.displayTitle)"
        weatherLabel.text = weatherText(diary.weather)
        weatherLabel.isHidden = weatherLabel.text?.isEmpty == true
        contentLabel.text = diary.content
        imageSummaryView.configure(imagePaths: imagePaths)
        imageSummaryView.isHidden = imagePaths.isEmpty
        imageHeightConstraint?.update(offset: imagePaths.isEmpty ? 0 : imageSummaryView.preferredHeight)
        locationLabel.text = "📍 \(diary.location?.name ?? diary.location?.district ?? diary.location?.city ?? "未记录地点")"
        configureTags(tags)
        favoriteButton.setImage(UIImage(systemName: diary.isFavorite ? "star.fill" : "star"), for: .normal)
        favoriteButton.tintColor = diary.isFavorite ? ViewDayTheme.accent : ViewDayTheme.iconSecondary
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none

        timelineLineView.backgroundColor = ViewDayTheme.border

        markerView.backgroundColor = ViewDayTheme.accent
        markerView.layer.cornerRadius = 4.5
        markerView.layer.borderWidth = 2
        markerView.layer.borderColor = ViewDayTheme.background.cgColor

        cardView.backgroundColor = ViewDayTheme.cardBackground
        cardView.layer.cornerRadius = 8
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = ViewDayTheme.border.cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.04
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 5)

        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = ViewDayTheme.secondaryText

        moodLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        moodLabel.textColor = ViewDayTheme.primaryText
        moodLabel.backgroundColor = ViewDayTheme.background
        moodLabel.layer.cornerRadius = 12
        moodLabel.clipsToBounds = true

        weatherLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        weatherLabel.textColor = ViewDayTheme.secondaryText
        weatherLabel.textAlignment = .right

        contentLabel.font = .systemFont(ofSize: 15, weight: .regular)
        contentLabel.textColor = ViewDayTheme.primaryText
        contentLabel.numberOfLines = 4
        contentLabel.lineBreakMode = .byTruncatingTail

        locationLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        locationLabel.textColor = ViewDayTheme.secondaryText
        locationLabel.numberOfLines = 1

        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 8
        tagsStackView.alignment = .leading

        favoriteButton.tintColor = ViewDayTheme.iconSecondary
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
        imageSummaryView.onPreferredHeightChange = { [weak self] height in
            self?.imageHeightConstraint?.update(offset: height)
        }

        contentView.addSubview(timelineLineView)
        contentView.addSubview(markerView)
        contentView.addSubview(cardView)
        cardView.addSubview(timeLabel)
        cardView.addSubview(moodLabel)
        cardView.addSubview(weatherLabel)
        cardView.addSubview(contentLabel)
        cardView.addSubview(imageSummaryView)
        cardView.addSubview(locationLabel)
        cardView.addSubview(tagsStackView)
        cardView.addSubview(favoriteButton)

        timelineLineView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.centerX.equalTo(markerView)
            make.width.equalTo(1)
        }

        markerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(28)
            make.width.height.equalTo(9)
        }

        cardView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.leading.equalTo(markerView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
        }

        timeLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(14)
        }

        moodLabel.snp.makeConstraints { make in
            make.leading.equalTo(timeLabel.snp.trailing).offset(10)
            make.centerY.equalTo(timeLabel)
            make.trailing.lessThanOrEqualTo(weatherLabel.snp.leading).offset(-10)
        }

        weatherLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(14)
            make.centerY.equalTo(timeLabel)
        }

        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(14)
        }

        imageSummaryView.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(14)
            imageHeightConstraint = make.height.equalTo(0).constraint
        }

        locationLabel.snp.makeConstraints { make in
            make.top.equalTo(imageSummaryView.snp.bottom).offset(12)
            make.leading.equalToSuperview().inset(14)
            make.trailing.lessThanOrEqualTo(favoriteButton.snp.leading).offset(-12)
        }

        tagsStackView.snp.makeConstraints { make in
            make.top.equalTo(locationLabel.snp.bottom).offset(10)
            make.leading.equalToSuperview().inset(14)
            make.trailing.lessThanOrEqualTo(favoriteButton.snp.leading).offset(-12)
            make.bottom.equalToSuperview().inset(14)
        }

        favoriteButton.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview().inset(14)
            make.width.height.equalTo(30)
        }
    }

    @objc private func favoriteButtonTapped() {
        onFavoriteToggle?()
    }

    private func configureTags(_ tags: [Tag]) {
        tagsStackView.arrangedSubviews.forEach { view in
            tagsStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        tagsStackView.isHidden = tags.isEmpty

        if tags.isEmpty {
            return
        }

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

    private func weatherText(_ weather: WeatherSnapshot?) -> String {
        guard let weather else { return "" }
        if let temperature = weather.temperature, let condition = weather.condition {
            return "\(weatherIcon(for: condition)) \(Int(temperature.rounded()))°C \(condition)"
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
}

private final class DiaryImageSummaryView: UIView {
    private let gridView = UIView()
    private let countLabel = PaddingLabel()
    private var imageViews: [UIImageView] = []
    private var imagePaths: [String] = []
    private var lastLayoutWidth: CGFloat = 0
    var onPreferredHeightChange: ((CGFloat) -> Void)?
    private(set) var preferredHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(imagePaths: [String]) {
        self.imagePaths = imagePaths
        gridView.subviews.forEach { $0.removeFromSuperview() }
        countLabel.removeFromSuperview()
        imageViews = []

        let images = imagePaths.prefix(3).compactMap { UIImage(contentsOfFile: $0) }
        let extraCount = max(0, imagePaths.count - 3)
        let nextHeight = images.isEmpty ? 0 : gridHeight(for: images.count)
        if abs(nextHeight - preferredHeight) > 0.5 {
            preferredHeight = nextHeight
            onPreferredHeightChange?(nextHeight)
        } else {
            preferredHeight = nextHeight
        }

        images.enumerated().forEach { index, image in
            let imageView = makeImageView(image: image)
            imageViews.append(imageView)
            gridView.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                let column = index % 3
                let row = index / 3
                make.width.height.equalTo(gridItemSide())
                make.top.equalToSuperview().offset(CGFloat(row) * (gridItemSide() + 8))
                make.leading.equalToSuperview().offset(CGFloat(column) * (gridItemSide() + 8))
            }
        }

        countLabel.isHidden = extraCount == 0 || images.isEmpty
        countLabel.text = extraCount > 0 ? "+\(extraCount)" : nil
        if extraCount > 0, let lastImageView = imageViews.last {
            lastImageView.addSubview(countLabel)
            countLabel.snp.remakeConstraints { make in
                make.trailing.bottom.equalToSuperview().inset(5)
                make.height.equalTo(20)
                make.width.greaterThanOrEqualTo(28)
            }
        }
    }

    private func setup() {
        backgroundColor = ViewDayTheme.background
        layer.cornerRadius = 8
        clipsToBounds = true

        countLabel.font = .systemFont(ofSize: 11, weight: .bold)
        countLabel.textColor = .white
        countLabel.backgroundColor = UIColor.black.withAlphaComponent(0.62)
        countLabel.layer.cornerRadius = 10
        countLabel.clipsToBounds = true
        countLabel.isHidden = true

        addSubview(gridView)

        gridView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !imagePaths.isEmpty, abs(bounds.width - lastLayoutWidth) > 0.5 else { return }
        lastLayoutWidth = bounds.width
        configure(imagePaths: imagePaths)
    }

    private func makeImageView(image: UIImage) -> UIImageView {
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = ViewDayTheme.cardBackground
        return imageView
    }

    private func gridItemSide() -> CGFloat {
        let availableWidth = bounds.width > 0 ? bounds.width - 16 : UIScreen.main.bounds.width - 116
        return floor((max(availableWidth, 240) - 16) / 3)
    }

    private func gridHeight(for count: Int) -> CGFloat {
        let rowCount = Int(ceil(Double(count) / 3.0))
        return CGFloat(rowCount) * gridItemSide() + CGFloat(max(0, rowCount - 1)) * 8 + 16
    }
}

private final class PaddingLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + contentInsets.left + contentInsets.right, height: size.height + contentInsets.top + contentInsets.bottom)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}
