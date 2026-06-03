import SnapKit
import UIKit

/// 记录文本输入卡片回调。
protocol RecordTextInputCardViewDelegate: AnyObject {
    func recordTextInputCardViewDidTapLocation(_ view: RecordTextInputCardView)
    func recordTextInputCardViewDidTapWeather(_ view: RecordTextInputCardView)
}

/// 记录页文本输入卡片。
/// 支持正文输入，并展示可点击的时间、地点、天气元信息。
final class RecordTextInputCardView: UIView {
    weak var delegate: RecordTextInputCardViewDelegate?

    let textView = UITextView()
    private let titleLabel = UILabel()
    private let metadataRowView = RecordMetadataRowView()
    private let placeholder: String

    var textValue: String {
        guard !isShowingPlaceholder else { return "" }
        return textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isShowingPlaceholder = true

    init(title: String, placeholder: String) {
        self.placeholder = placeholder
        super.init(frame: .zero)
        setup(title: title, placeholder: placeholder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configureMetadata(items: [(symbolName: String, text: String)]) {
        metadataRowView.configure(items: items)
    }

    func clearText() {
        isShowingPlaceholder = true
        textView.text = placeholder
        textView.textColor = ViewDayTheme.secondaryText
    }

    func setText(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            clearText()
            return
        }

        isShowingPlaceholder = false
        textView.text = text
        textView.textColor = ViewDayTheme.primaryText
    }

    private func setup(title: String, placeholder: String) {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = ViewDayTheme.secondaryText
        textView.text = placeholder
        textView.delegate = self
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        addSubview(titleLabel)
        addSubview(textView)
        addSubview(metadataRowView)
        metadataRowView.delegate = self

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        textView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.greaterThanOrEqualTo(128)
        }

        metadataRowView.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(14)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.equalTo(30)
        }
    }
}

extension RecordTextInputCardView: RecordMetadataRowViewDelegate {
    func recordMetadataRowViewDidTapLocation(_ view: RecordMetadataRowView) {
        delegate?.recordTextInputCardViewDidTapLocation(self)
    }

    func recordMetadataRowViewDidTapWeather(_ view: RecordMetadataRowView) {
        delegate?.recordTextInputCardViewDidTapWeather(self)
    }
}

extension RecordTextInputCardView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        guard isShowingPlaceholder else { return }
        isShowingPlaceholder = false
        textView.text = ""
        textView.textColor = ViewDayTheme.primaryText
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        clearText()
    }
}
