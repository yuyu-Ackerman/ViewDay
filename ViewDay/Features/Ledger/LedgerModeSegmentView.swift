import SnapKit
import UIKit

/// 账本模式切换回调。
protocol LedgerModeSegmentViewDelegate: AnyObject {
    func ledgerModeSegmentView(_ view: LedgerModeSegmentView, didSelect mode: LedgerMode)
}

/// 账本展示模式。
enum LedgerMode: Int, CaseIterable {
    case overview
    case expense
    case income

    var title: String {
        switch self {
        case .overview:
            return "总览"
        case .expense:
            return "支出"
        case .income:
            return "收入"
        }
    }
}

/// 账本模式切换控件。
/// 用于在统计视图和流水列表视图之间切换。
final class LedgerModeSegmentView: UIView {
    weak var delegate: LedgerModeSegmentViewDelegate?

    private let stackView = UIStackView()
    private var selectedMode: LedgerMode = .overview
    private var buttons: [LedgerMode: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        backgroundColor = ViewDayTheme.controlBackground
        layer.cornerRadius = 8
        layer.borderWidth = 0

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 6

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
            make.height.equalTo(36)
        }

        LedgerMode.allCases.forEach { mode in
            let button = UIButton(type: .system)
            button.tag = mode.rawValue
            button.setTitle(mode.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.layer.cornerRadius = 7
            button.addTarget(self, action: #selector(modeButtonTapped(_:)), for: .touchUpInside)
            buttons[mode] = button
            stackView.addArrangedSubview(button)
        }

        updateButtonStates()
    }

    @objc private func modeButtonTapped(_ sender: UIButton) {
        guard let mode = LedgerMode(rawValue: sender.tag) else { return }
        selectedMode = mode
        updateButtonStates()
        delegate?.ledgerModeSegmentView(self, didSelect: mode)
    }

    private func updateButtonStates() {
        buttons.forEach { mode, button in
            let isSelected = mode == selectedMode
            button.backgroundColor = isSelected ? ViewDayTheme.cardBackground : .clear
            button.setTitleColor(isSelected ? ViewDayTheme.accent : ViewDayTheme.secondaryText, for: .normal)
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = isSelected ? 0.04 : 0
            button.layer.shadowRadius = isSelected ? 6 : 0
            button.layer.shadowOffset = CGSize(width: 0, height: 3)
        }
    }
}
