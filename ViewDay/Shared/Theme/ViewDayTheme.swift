import UIKit

/// ViewDay 全局视觉主题。
/// 所有页面共用这里的颜色，保证深浅色模式和品牌色调整集中生效。
enum ViewDayTheme {
    /// 品牌强调色，用于主要按钮、选中态和关键数值。
    static let accent = UIColor { _ in UIColor(red: 0.714, green: 1.0, blue: 0.231, alpha: 1.0) }
    static let deepSpace = UIColor(red: 0.027, green: 0.078, blue: 0.149, alpha: 1.0)
    static let cardDark = UIColor(red: 0.059, green: 0.106, blue: 0.176, alpha: 1.0)
    static let separatorDark = UIColor(red: 0.102, green: 0.141, blue: 0.212, alpha: 1.0)
    static let textMuted = UIColor(red: 0.541, green: 0.58, blue: 0.651, alpha: 1.0)
    static let iconPrimary = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0) : UIColor(red: 0.08, green: 0.11, blue: 0.16, alpha: 1.0)
    }
    static let iconSecondary = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.66, green: 0.70, blue: 0.76, alpha: 1.0) : UIColor(red: 0.48, green: 0.52, blue: 0.58, alpha: 1.0)
    }
    static let controlBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.07) : UIColor(red: 0.953, green: 0.957, blue: 0.965, alpha: 1.0)
    }

    /// 页面背景色。
    static let background = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? deepSpace : UIColor(red: 0.969, green: 0.973, blue: 0.98, alpha: 1.0)
    }

    /// 默认卡片背景色。
    static let cardBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? cardDark.withAlphaComponent(0.92) : .white
    }

    /// 浮层或强调卡片背景色。
    static let elevatedCardBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.075) : .white
    }

    static let primaryText = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? .white : UIColor(red: 0.027, green: 0.078, blue: 0.149, alpha: 1.0)
    }

    static let secondaryText = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor(red: 0.76, green: 0.79, blue: 0.84, alpha: 1.0) : textMuted
    }

    static let border = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.08) : UIColor(red: 0.878, green: 0.894, blue: 0.922, alpha: 1.0)
    }
}
