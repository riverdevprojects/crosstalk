import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: NSObject, ObservableObject {
    @Published var text = ""
    @Published var isRecording = false
    @Published var errorText: String?

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        SFSpeechRecognizer.requestAuthorization { auth in
            Task { @MainActor in
                guard auth == .authorized else { self.errorText = "Speech permission is needed for voice guesses."; return }
                self.beginRecording()
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
    }

    private func beginRecording() {
        task?.cancel(); task = nil; text = ""; errorText = nil
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            request = SFSpeechAudioBufferRecognitionRequest()
            guard let request else { return }
            request.shouldReportPartialResults = true
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
            task = recognizer?.recognitionTask(with: request) { result, error in
                Task { @MainActor in
                    if let result { self.text = result.bestTranscription.formattedString }
                    if error != nil { self.stop() }
                }
            }
        } catch {
            errorText = error.localizedDescription
            isRecording = false
        }
    }
}
