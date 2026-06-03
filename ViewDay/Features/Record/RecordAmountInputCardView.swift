import SnapKit
import UIKit

/// 账本金额输入卡片。
/// 同时管理金额输入和收入/支出方向切换。
final class RecordAmountInputCardView: UIControl {
    let amountTextField = UITextField()
    let typeControl = UISegmentedControl(items: ["支出", "收入"])

    var transactionType: TransactionType {
        typeControl.selectedSegmentIndex == 0 ? .expense : .income
    }

    var amount: Decimal? {
        guard let text = amountTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }

        let normalizedText = text
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Decimal(string: normalizedText)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        let titleLabel = UILabel()
        titleLabel.text = "金额"
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        amountTextField.placeholder = "¥ 0.00"
        amountTextField.keyboardType = .decimalPad
        amountTextField.font = .systemFont(ofSize: 38, weight: .bold)
        amountTextField.textColor = ViewDayTheme.primaryText
        amountTextField.tintColor = ViewDayTheme.iconPrimary

        typeControl.selectedSegmentIndex = 0
        typeControl.backgroundColor = ViewDayTheme.controlBackground
        typeControl.selectedSegmentTintColor = ViewDayTheme.cardBackground
        typeControl.setTitleTextAttributes([.foregroundColor: ViewDayTheme.secondaryText], for: .normal)
        typeControl.setTitleTextAttributes([.foregroundColor: ViewDayTheme.accent], for: .selected)
        typeControl.addTarget(self, action: #selector(typeDidChange), for: .valueChanged)

        addSubview(titleLabel)
        addSubview(amountTextField)
        addSubview(typeControl)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        amountTextField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(54)
        }

        typeControl.snp.makeConstraints { make in
            make.top.equalTo(amountTextField.snp.bottom).offset(14)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.equalTo(36)
        }
    }

    @objc private func typeDidChange() {
        sendActions(for: .valueChanged)
    }
}
