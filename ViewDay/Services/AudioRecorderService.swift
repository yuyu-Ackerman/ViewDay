import AVFoundation
import Foundation

/// 录音服务错误。
enum AudioRecorderServiceError: Error {
    /// 麦克风权限未授权。
    case permissionDenied
    /// 系统 Documents 目录不可用。
    case documentsDirectoryUnavailable
    /// 当前录音器状态异常，无法开始或复用录音。
    case recorderUnavailable
}

/// 录音服务协议。
/// 记录页通过协议控制录音，避免直接持有 AVFoundation 细节。
protocol AudioRecorderServiceProtocol {
    var isRecording: Bool { get }
    func requestPermission(completion: @escaping (Bool) -> Void)
    func startRecording() throws -> URL
    func stopRecording() -> URL?
}

/// 面向记录页的一次录音服务。
/// 录音文件与图片附件共用 Documents/Attachments 目录，保存后由附件仓储统一关联业务对象。
final class AudioRecorderService: NSObject, AudioRecorderServiceProtocol {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

    var isRecording: Bool {
        recorder?.isRecording == true
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            // 权限结果可能从后台线程返回，页面更新必须切回主线程。
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func startRecording() throws -> URL {
        guard !isRecording else {
            if let currentURL { return currentURL }
            throw AudioRecorderServiceError.recorderUnavailable
        }

        let url = try makeAudioURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // 使用 playAndRecord 并默认外放，避免录音结束后预览播放走听筒。
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.record()

        self.recorder = recorder
        currentURL = url
        return url
    }

    func stopRecording() -> URL? {
        guard isRecording else { return currentURL }
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return currentURL
    }

    private func makeAudioURL() throws -> URL {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AudioRecorderServiceError.documentsDirectoryUnavailable
        }

        let directory = documentsURL.appendingPathComponent("Attachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent("\(UUID().uuidString).m4a")
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
}
