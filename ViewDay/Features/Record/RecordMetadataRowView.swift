import SnapKit
import UIKit

/// 记录元信息行回调。
protocol RecordMetadataRowViewDelegate: AnyObject {
    func recordMetadataRowViewDidTapLocation(_ view: RecordMetadataRowView)
    func recordMetadataRowViewDidTapWeather(_ view: RecordMetadataRowView)
}

/// 记录卡片中的元信息行。
/// 用图标和短文本展示时间、地点、天气等可编辑上下文。
final class RecordMetadataRowView: UIView {
    weak var delegate: RecordMetadataRowViewDelegate?

    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(items: [(symbolName: String, text: String)]) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        items.forEach { item in
            stackView.addArrangedSubview(makeChip(symbolName: item.symbolName, text: item.text))
        }
    }

    private func setup() {
        stackView.axis = .horizontal
        stackView.alignment = .leading
        stackView.spacing = 8
        stackView.distribution = .fill

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func makeChip(symbolName: String, text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = ViewDayTheme.background
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = ViewDayTheme.border.cgColor
        container.isUserInteractionEnabled = symbolName == "location" || symbolName == "sun.max"

        let imageView = UIImageView(image: UIImage(systemName: symbolName))
        imageView.tintColor = ViewDayTheme.secondaryText
        imageView.contentMode = .scaleAspectFill

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = ViewDayTheme.secondaryText
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.lineBreakMode = .byTruncatingTail

        container.addSubview(imageView)
        container.addSubview(label)

        if symbolName == "location" {
            container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(locationChipTapped)))
        } else if symbolName == "sun.max" {
            container.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(weatherChipTapped)))
        }

        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }

        label.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(5)
            make.trailing.equalToSuperview().inset(10)
            make.top.bottom.equalToSuperview().inset(7)
        }

        if symbolName == "clock" {
            container.setContentCompressionResistancePriority(.required, for: .horizontal)
            container.snp.makeConstraints { make in
                make.width.equalTo(112)
            }
        } else if symbolName == "sun.max" {
            container.setContentCompressionResistancePriority(.required, for: .horizontal)
            container.snp.makeConstraints { make in
                make.width.equalTo(116)
            }
        } else if symbolName == "location" {
            container.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        return container
    }

    @objc private func locationChipTapped() {
        delegate?.recordMetadataRowViewDidTapLocation(self)
    }

    @objc private func weatherChipTapped() {
        delegate?.recordMetadataRowViewDidTapWeather(self)
    }
}
