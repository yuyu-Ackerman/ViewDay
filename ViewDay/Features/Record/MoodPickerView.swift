import SnapKit
import UIKit

/// 情绪选择器回调。
protocol MoodPickerViewDelegate: AnyObject {
    func moodPickerView(_ view: MoodPickerView, didSelect mood: MoodType)
}

/// 日记情绪选择器。
/// 以横向按钮组展示可选情绪，并维护当前选中态。
final class MoodPickerView: UIView {
    weak var delegate: MoodPickerViewDelegate?

    private let stackView = UIStackView()
    private var selectedMood: MoodType
    private var buttons: [MoodType: UIButton] = [:]

    init(selectedMood: MoodType = .calm) {
        self.selectedMood = selectedMood
        super.init(frame: .zero)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func setSelectedMood(_ mood: MoodType) {
        selectedMood = mood
        updateButtonStates()
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderColor = ViewDayTheme.border.cgColor
        layer.borderWidth = 1

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
            make.height.equalTo(68)
        }

        MoodType.allCases.forEach { mood in
            let button = UIButton(type: .system)
            button.tag = MoodType.allCases.firstIndex(of: mood) ?? 0
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.layer.cornerRadius = 10
            button.addTarget(self, action: #selector(moodButtonTapped(_:)), for: .touchUpInside)
            buttons[mood] = button
            stackView.addArrangedSubview(button)
        }

        updateButtonStates()
    }

    private func updateButtonStates() {
        buttons.forEach { mood, button in
            let isSelected = mood == selectedMood
            button.backgroundColor = isSelected ? ViewDayTheme.controlBackground : .clear
            button.layer.borderWidth = isSelected ? 1 : 0
            button.layer.borderColor = isSelected ? ViewDayTheme.accent.cgColor : UIColor.clear.cgColor
            let iconColor = isSelected ? ViewDayTheme.iconPrimary : ViewDayTheme.iconSecondary
            let titleColor = isSelected ? ViewDayTheme.accent : ViewDayTheme.secondaryText
            let attributedTitle = NSMutableAttributedString(
                string: "\(iconText(for: mood))\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 28, weight: .regular),
                    .foregroundColor: iconColor
                ]
            )
            attributedTitle.append(NSAttributedString(
                string: titleText(for: mood),
                attributes: [
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: titleColor
                ]
            ))
            button.setAttributedTitle(attributedTitle, for: .normal)
        }
    }

    @objc private func moodButtonTapped(_ sender: UIButton) {
        let mood = MoodType.allCases[sender.tag]
        selectedMood = mood
        updateButtonStates()
        delegate?.moodPickerView(self, didSelect: mood)
    }

    private func iconText(for mood: MoodType) -> String {
        switch mood {
        case .calm:
            return "🙂"
        case .happy:
            return "😊"
        case .tired:
            return "😫"
        case .anxious:
            return "😟"
        case .grateful:
            return "😄"
        }
    }

    private func titleText(for mood: MoodType) -> String {
        switch mood {
        case .calm:
            return "平静"
        case .happy:
            return "开心"
        case .tired:
            return "疲惫"
        case .anxious:
            return "焦虑"
        case .grateful:
            return "感恩"
        }
    }
}
