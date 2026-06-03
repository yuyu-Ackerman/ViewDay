import UIKit

/// 手动天气编辑器。
/// 当自动天气获取失败或用户需要覆盖天气时，通过轻量 alert 生成手动天气快照。
enum ManualWeatherEditor {
    /// 展示手动天气输入框。
    ///
    /// - Parameter presenter: 负责弹出 alert 的控制器。
    /// - Parameter existingWeather: 用于回填温度和天气描述的现有快照。
    /// - Parameter onSave: 保存后返回可写入记录的天气快照。
    static func present(from presenter: UIViewController, existingWeather: WeatherSnapshot?, onSave: @escaping (WeatherSnapshot) -> Void) {
        let alertController = UIAlertController(title: "手动填写天气", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "温度，例如 22"
            textField.keyboardType = .decimalPad
            if let temperature = existingWeather?.temperature {
                textField.text = String(Int(temperature.rounded()))
            }
        }
        alertController.addTextField { textField in
            textField.placeholder = "天气，例如 晴、多云、小雨"
            textField.text = existingWeather?.condition
        }

        alertController.addAction(UIAlertAction(title: "取消", style: .cancel))
        alertController.addAction(UIAlertAction(title: "保存", style: .default) { [weak alertController] _ in
            let temperatureText = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let condition = alertController?.textFields?.dropFirst().first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            let temperature = Double(temperatureText)

            guard temperature != nil || condition?.isEmpty == false else {
                return
            }

            onSave(WeatherSnapshot(
                temperature: temperature,
                condition: condition?.isEmpty == true ? nil : condition,
                conditionCode: nil,
                humidity: nil,
                windSpeed: nil,
                provider: "Manual",
                fetchedAt: Date()
            ))
        })

        presenter.present(alertController, animated: true)
    }
}
