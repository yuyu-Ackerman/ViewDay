import AVFoundation
import SnapKit
import UIKit

/// 音频附件播放视图。
/// 用于详情页播放已保存的语音附件，并封装 AVAudioPlayer 的生命周期。
final class AudioAttachmentPlayerView: UIView {
    private let titleLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let durationLabel = UILabel()
    private var player: AVAudioPlayer?
    private var audioURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(audioPath: String?) {
        guard let audioPath else {
            isHidden = true
            return
        }

        let url = URL(fileURLWithPath: audioPath)
        audioURL = url
        isHidden = false

        // 配置阶段只读取时长，真正播放时再创建 player，避免列表复用时长期占用音频资源。
        if let player = try? AVAudioPlayer(contentsOf: url) {
            durationLabel.text = durationText(player.duration)
        } else {
            durationLabel.text = "无法播放"
        }
    }

    private func setup() {
        backgroundColor = ViewDayTheme.cardBackground
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ViewDayTheme.border.cgColor

        titleLabel.text = "语音"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = ViewDayTheme.primaryText

        playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playButton.tintColor = ViewDayTheme.iconPrimary
        playButton.backgroundColor = ViewDayTheme.controlBackground
        playButton.layer.cornerRadius = 18
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)

        durationLabel.font = .systemFont(ofSize: 14, weight: .medium)
        durationLabel.textColor = ViewDayTheme.secondaryText

        addSubview(titleLabel)
        addSubview(playButton)
        addSubview(durationLabel)

        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        playButton.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(14)
            make.leading.bottom.equalToSuperview().inset(16)
            make.width.height.equalTo(36)
        }

        durationLabel.snp.makeConstraints { make in
            make.leading.equalTo(playButton.snp.trailing).offset(12)
            make.centerY.equalTo(playButton)
            make.trailing.equalToSuperview().inset(16)
        }
    }

    @objc private func playButtonTapped() {
        guard let audioURL else { return }

        if player?.isPlaying == true {
            player?.stop()
            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // 详情页播放语音时使用 playback，避免静音开关影响用户主动点击后的回放。
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: audioURL)
            self.player = player
            player.play()
            playButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        } catch {
            durationLabel.text = "播放失败"
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
