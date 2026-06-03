import SnapKit
import UIKit

/// 日记筛选栏回调。
protocol DiaryFilterBarViewDelegate: AnyObject {
    func diaryFilterBarView(_ view: DiaryFilterBarView, didSelect filter: DiaryFilter)
}

/// 日记列表筛选类型。
enum DiaryFilter: Int, CaseIterable {
    case all
    case image
    case mood
    case favorite

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .image:
            return "图文"
        case .mood:
            return "心情"
        case .favorite:
            return "收藏"
        }
    }
}

/// 日记筛选栏视图。
/// 负责在全部、收藏、草稿等筛选条件之间切换。
final class DiaryFilterBarView: UIView {
    weak var delegate: DiaryFilterBarViewDelegate?

    private let stackView = UIStackView()
    private var selectedFilter: DiaryFilter = .all
    private var buttons: [DiaryFilter: UIButton] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8

        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(36)
        }

        DiaryFilter.allCases.forEach { filter in
            let button = UIButton(type: .system)
            button.tag = filter.rawValue
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            button.layer.cornerRadius = 8
            button.setTitle(filter.title, for: .normal)
            button.addTarget(self, action: #selector(filterButtonTapped(_:)), for: .touchUpInside)
            buttons[filter] = button
            stackView.addArrangedSubview(button)
        }

        updateButtonStates()
    }

    @objc private func filterButtonTapped(_ sender: UIButton) {
        guard let filter = DiaryFilter(rawValue: sender.tag) else { return }
        selectedFilter = filter
        updateButtonStates()
        delegate?.diaryFilterBarView(self, didSelect: filter)
    }

    private func updateButtonStates() {
        buttons.forEach { filter, button in
            let isSelected = filter == selectedFilter
            button.backgroundColor = .clear
            button.layer.borderWidth = 0
            let title = filter.title
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: isSelected ? ViewDayTheme.accent : ViewDayTheme.secondaryText,
                .underlineStyle: isSelected ? NSUnderlineStyle.single.rawValue : 0,
                .underlineColor: ViewDayTheme.accent
            ]
            button.setAttributedTitle(NSAttributedString(string: title, attributes: attributes), for: .normal)
        }
    }
}
