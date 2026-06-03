import SnapKit
import UIKit

/// 账本余额走势图。
/// 根据月内每日累计余额点绘制折线图。
final class LedgerBalanceChartView: UIView {
    private let titleLabel = UILabel()
    private let unitLabel = UILabel()
    private var points: [DailyBalancePoint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(points: [DailyBalancePoint]) {
        self.points = points
        setNeedsDisplay()
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.05
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        titleLabel.text = "本月结余趋势"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        unitLabel.text = "结余（元）"
        unitLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        unitLabel.textColor = ViewDayTheme.secondaryText

        addSubview(titleLabel)
        addSubview(unitLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
        }

        unitLabel.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.trailing.equalToSuperview().inset(16)
        }

        snp.makeConstraints { make in
            make.height.equalTo(180)
        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else { return }
        // 预留左侧纵轴和底部日期标签空间，避免图形与文字重叠。
        let chartRect = CGRect(x: 48, y: 60, width: rect.width - 72, height: rect.height - 86)
        let scale = yAxisScale()
        drawGrid(in: chartRect, context: context)
        drawYAxisLabels(in: chartRect, labels: scale.labels)
        drawLine(in: chartRect, context: context, minValue: scale.min, maxValue: scale.max)
        drawXAxisLabels(in: chartRect)
    }

    private func drawGrid(in rect: CGRect, context: CGContext) {
        context.setStrokeColor(ViewDayTheme.border.withAlphaComponent(0.72).cgColor)
        context.setLineWidth(1)

        for index in 0...3 {
            let y = rect.minY + rect.height * CGFloat(index) / 3
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        context.strokePath()
    }

    private func drawLine(in rect: CGRect, context: CGContext, minValue: Double, maxValue: Double) {
        guard points.count > 1 else {
            drawEmptyHint(in: rect)
            return
        }

        let range = max(maxValue - minValue, 1)
        let chartPoints = points.enumerated().map { index, point -> CGPoint in
            let value = NSDecimalNumber(decimal: point.balance).doubleValue
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(points.count - 1)
            let y = rect.maxY - rect.height * CGFloat((value - minValue) / range)
            return CGPoint(x: x, y: y)
        }

        // 使用平滑曲线而不是折线，让月度趋势在小卡片中更容易扫读。
        let linePath = smoothedPath(points: chartPoints)
        let fillPath = linePath.copy() as? UIBezierPath ?? UIBezierPath()
        fillPath.addLine(to: CGPoint(x: chartPoints.last?.x ?? rect.maxX, y: rect.maxY))
        fillPath.addLine(to: CGPoint(x: chartPoints.first?.x ?? rect.minX, y: rect.maxY))
        fillPath.close()

        context.saveGState()
        fillPath.addClip()
        let colors = [
            ViewDayTheme.accent.withAlphaComponent(0.12).cgColor,
            ViewDayTheme.accent.withAlphaComponent(0.0).cgColor
        ] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
        context.restoreGState()

        ViewDayTheme.accent.setStroke()
        linePath.lineWidth = 3
        linePath.lineCapStyle = .round
        linePath.lineJoinStyle = .round
        linePath.stroke()

        chartPoints.enumerated().forEach { index, point in
            guard index == 0 || index == chartPoints.count - 1 || index % max(1, chartPoints.count / 4) == 0 else { return }
            let dotRect = CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)
            ViewDayTheme.cardBackground.setFill()
            UIBezierPath(ovalIn: dotRect.insetBy(dx: -2, dy: -2)).fill()
            ViewDayTheme.accent.setFill()
            UIBezierPath(ovalIn: dotRect).fill()
        }
    }

    private func smoothedPath(points: [CGPoint]) -> UIBezierPath {
        let path = UIBezierPath()
        guard let firstPoint = points.first else { return path }
        path.move(to: firstPoint)

        for index in 1..<points.count {
            let previousPoint = points[index - 1]
            let currentPoint = points[index]
            let midPoint = CGPoint(x: (previousPoint.x + currentPoint.x) / 2, y: (previousPoint.y + currentPoint.y) / 2)
            path.addQuadCurve(to: midPoint, controlPoint: previousPoint)
            path.addQuadCurve(to: currentPoint, controlPoint: currentPoint)
        }

        return path
    }

    private func drawXAxisLabels(in rect: CGRect) {
        guard !points.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M/d"

        let labelPoints = [0, max(0, points.count / 2), max(0, points.count - 1)]
        labelPoints.forEach { index in
            guard points.indices.contains(index) else { return }
            let text = formatter.string(from: points[index].date) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: ViewDayTheme.secondaryText
            ]
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: min(max(rect.minX, x - size.width / 2), rect.maxX - size.width), y: rect.maxY + 10), withAttributes: attributes)
        }
    }

    private func drawYAxisLabels(in rect: CGRect, labels: [Double]) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: ViewDayTheme.secondaryText
        ]
        labels.enumerated().forEach { index, label in
            let text = compactAmountText(label) as NSString
            let size = text.size(withAttributes: attributes)
            let y = rect.minY + rect.height * CGFloat(index) / CGFloat(labels.count - 1) - size.height / 2
            text.draw(at: CGPoint(x: rect.minX - size.width - 8, y: y), withAttributes: attributes)
        }
    }

    private func yAxisScale() -> (min: Double, max: Double, labels: [Double]) {
        let values = points.map { NSDecimalNumber(decimal: $0.balance).doubleValue } + [0]
        guard let rawMin = values.min(), let rawMax = values.max() else {
            return (-1, 1, [1, 0.5, 0, -0.5, -1])
        }

        // 即使所有余额接近，也保留最小跨度，避免曲线被压到图表边缘。
        let span = max(rawMax - rawMin, max(abs(rawMax), abs(rawMin), 1) * 0.2)
        let padding = span * 0.16
        let minValue = niceFloor(rawMin - padding)
        let maxValue = niceCeil(rawMax + padding)
        let step = (maxValue - minValue) / 4
        let labels = (0...4).map { maxValue - Double($0) * step }
        return (minValue, maxValue, labels)
    }

    private func niceFloor(_ value: Double) -> Double {
        guard value != 0 else { return 0 }
        let step = niceStep(for: abs(value))
        return floor(value / step) * step
    }

    private func niceCeil(_ value: Double) -> Double {
        guard value != 0 else { return 0 }
        let step = niceStep(for: abs(value))
        return ceil(value / step) * step
    }

    private func niceStep(for magnitude: Double) -> Double {
        // 让纵轴刻度落在 0.2、0.5、1 倍数量级上，标签比原始小数更稳定。
        let exponent = floor(log10(max(magnitude, 1)))
        let base = pow(10, exponent)
        let normalized = magnitude / base
        if normalized <= 2 { return base / 5 }
        if normalized <= 5 { return base / 2 }
        return base
    }

    private func compactAmountText(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded) >= 10_000 {
            let text = String(format: "%.1f万", rounded / 10_000)
            return text.replacingOccurrences(of: ".0万", with: "万")
        }
        if abs(rounded) >= 1_000 {
            let text = String(format: "%.1fK", rounded / 1_000)
            return text.replacingOccurrences(of: ".0K", with: "K")
        }
        return String(format: "%.0f", rounded)
    }

    private func drawEmptyHint(in rect: CGRect) {
        let text = "暂无趋势数据" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: ViewDayTheme.secondaryText
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
    }
}
