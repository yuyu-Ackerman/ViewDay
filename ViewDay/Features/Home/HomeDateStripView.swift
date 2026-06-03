import SnapKit
import UIKit

/// 首页日期条回调。
protocol HomeDateStripViewDelegate: AnyObject {
    func homeDateStripView(_ view: HomeDateStripView, didSelect date: Date)
}

/// 首页横向日期选择条。
/// 围绕当前日期生成一周视图，并通知外层刷新当天概览。
final class HomeDateStripView: UIView {
    weak var delegate: HomeDateStripViewDelegate?

    private let calendar: Calendar
    private let monthLabel = UILabel()
    private let todayButton = UIButton(type: .system)
    private let previousWeekButton = UIButton(type: .system)
    private let nextWeekButton = UIButton(type: .system)
    private let stackView = UIStackView()
    private var dates: [Date] = []
    private var weekAnchorDate: Date
    private var selectedDate: Date

    init(selectedDate: Date = Date(), calendar: Calendar = .current) {
        self.selectedDate = selectedDate
        self.calendar = calendar
        weekAnchorDate = selectedDate
        super.init(frame: .zero)
        setup()
        configure(around: selectedDate, selectedDate: selectedDate)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(around date: Date, selectedDate: Date) {
        self.selectedDate = selectedDate
        weekAnchorDate = date
        dates = makeWeekDates(containing: date)
        monthLabel.text = monthText(for: selectedDate)
        rebuildDateButtons()
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        monthLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        monthLabel.textColor = ViewDayTheme.primaryText

        todayButton.setTitle("今天", for: .normal)
        todayButton.setTitleColor(ViewDayTheme.secondaryText, for: .normal)
        todayButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        todayButton.addTarget(self, action: #selector(todayButtonTapped), for: .touchUpInside)

        configureWeekButton(previousWeekButton, imageName: "chevron.left", action: #selector(previousWeekButtonTapped))
        configureWeekButton(nextWeekButton, imageName: "chevron.right", action: #selector(nextWeekButtonTapped))

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 6

        addSubview(monthLabel)
        addSubview(previousWeekButton)
        addSubview(todayButton)
        addSubview(nextWeekButton)
        addSubview(stackView)

        monthLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
        }

        todayButton.snp.makeConstraints { make in
            make.centerY.equalTo(monthLabel)
            make.trailing.equalTo(nextWeekButton.snp.leading).offset(-4)
        }

        previousWeekButton.snp.makeConstraints { make in
            make.centerY.equalTo(monthLabel)
            make.trailing.equalTo(todayButton.snp.leading).offset(-8)
            make.width.height.equalTo(28)
        }

        nextWeekButton.snp.makeConstraints { make in
            make.centerY.equalTo(monthLabel)
            make.trailing.equalToSuperview().inset(14)
            make.width.height.equalTo(28)
        }

        stackView.snp.makeConstraints { make in
            make.top.equalTo(monthLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(12)
            make.height.equalTo(72)
        }
    }

    private func configureWeekButton(_ button: UIButton, imageName: String, action: Selector) {
        button.tintColor = ViewDayTheme.iconSecondary
        button.backgroundColor = ViewDayTheme.controlBackground
        button.layer.cornerRadius = 8
        button.setImage(UIImage(systemName: imageName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func rebuildDateButtons() {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        dates.forEach { date in
            let button = DateButton(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate), calendar: calendar)
            button.addTarget(self, action: #selector(dateButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    private func makeWeekDates(containing date: Date) -> [Date] {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }

    private func monthText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy年M月"
        return "\(formatter.string(from: date))"
    }

    @objc private func todayButtonTapped() {
        let today = Date()
        configure(around: today, selectedDate: today)
        delegate?.homeDateStripView(self, didSelect: today)
    }

    @objc private func dateButtonTapped(_ sender: DateButton) {
        selectedDate = sender.date
        monthLabel.text = monthText(for: sender.date)
        rebuildDateButtons()
        delegate?.homeDateStripView(self, didSelect: sender.date)
    }

    @objc private func previousWeekButtonTapped() {
        moveWeek(by: -1)
    }

    @objc private func nextWeekButtonTapped() {
        moveWeek(by: 1)
    }

    private func moveWeek(by value: Int) {
        let nextAnchorDate = calendar.date(byAdding: .weekOfYear, value: value, to: weekAnchorDate) ?? weekAnchorDate
        configure(around: nextAnchorDate, selectedDate: nextAnchorDate)
        delegate?.homeDateStripView(self, didSelect: nextAnchorDate)
    }

}

private final class DateButton: UIButton {
    let date: Date

    init(date: Date, isSelected: Bool, calendar: Calendar) {
        self.date = date
        super.init(frame: .zero)
        setup(date: date, isSelected: isSelected, calendar: calendar)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup(date: Date, isSelected: Bool, calendar: Calendar) {
        layer.cornerRadius = 12
        backgroundColor = isSelected ? ViewDayTheme.accent : .clear

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "zh_Hans_CN")
        weekdayFormatter.dateFormat = "EEEEE"

        let day = calendar.component(.day, from: date)
        let textColor = isSelected ? UIColor.black : ViewDayTheme.primaryText
        let subtitleColor = isSelected ? UIColor.black.withAlphaComponent(0.65) : ViewDayTheme.secondaryText

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6

        let attributedTitle = NSMutableAttributedString(
            string: "\(weekdayFormatter.string(from: date))\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: subtitleColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributedTitle.append(NSAttributedString(
            string: "\(day)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 23, weight: .bold),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        ))

        setAttributedTitle(attributedTitle, for: .normal)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
    }
}
