import SwiftUI
import AVFoundation

// MARK: - Model

enum TimerPhase: Equatable {
    case work
    case rest

    var duration: TimeInterval { self == .work ? 25 * 60 : 5 * 60 }
    var label: String { self == .work ? "作業" : "休憩" }
    var color: Color { self == .work ? .orange : .teal }
}

@MainActor @Observable
final class PomodoroModel {
    var totalSessions = 1
    var currentSession = 1
    var phase: TimerPhase = .work
    var remainingSeconds: TimeInterval = 25 * 60
    var isRunning = false
    var ringColor = Color.orange

    private var timerTask: Task<Void, Never>?
    private var tickCount = 0
    private var audioPlayer: AVAudioPlayer?

    // ランダムな周波数で正弦波トーンを生成
    private static let toneFrequencies: [Double] = [
        261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25,
        587.33, 659.25, 698.46, 783.99, 880.00, 987.77, 1046.50
    ]

    var elapsed: TimeInterval { phase.duration - remainingSeconds }
    var progress: Double { elapsed / phase.duration }

    var minutesDisplay: Int { Int(remainingSeconds) / 60 }
    var secondsDisplay: Int { Int(remainingSeconds) % 60 }

    var overallProgress: Double {
        let completedSessions = Double(currentSession - 1)
        let currentPhaseWeight: Double = phase == .work ? 0.0 : 0.5
        let inPhaseProgress = progress * (phase == .work ? 0.5 : 0.5)
        return (completedSessions + currentPhaseWeight + inPhaseProgress) / Double(totalSessions)
    }

    var sessionSummary: String {
        "\(currentSession) / \(totalSessions) セッション"
    }

    func start(sessions: Int) {
        totalSessions = sessions
        currentSession = 1
        phase = .work
        remainingSeconds = phase.duration
        isRunning = true
        tickCount = 0
        startTimer()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
        remainingSeconds = TimerPhase.work.duration
        phase = .work
        currentSession = 1
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && isRunning {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled && isRunning else { break }
                ringColor = Color(
                    hue: Double.random(in: 0...1),
                    saturation: Double.random(in: 0.5...1.0),
                    brightness: Double.random(in: 0.6...1.0)
                )
                tickCount += 1
                if tickCount % 5 == 0 {
                    playRandomSound()
                }
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    advancePhase()
                }
            }
        }
    }

    private func playRandomSound() {
        let freq = Self.toneFrequencies.randomElement() ?? 440.0
        guard let data = generateToneData(frequency: freq, duration: 0.3) else { return }
        audioPlayer = try? AVAudioPlayer(data: data)
        audioPlayer?.play()
    }

    private nonisolated func generateToneData(frequency: Double, duration: Double) -> Data? {
        let sampleRate: Double = 44100
        let sampleCount = Int(sampleRate * duration)
        let amplitude: Double = 0.5

        var header = Data()
        let dataSize = UInt32(sampleCount * 2)
        let fileSize = UInt32(36 + dataSize)

        // RIFF header
        header.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        header.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        header.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        // fmt chunk
        header.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        header.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits
        // data chunk
        header.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        var samples = Data(capacity: Int(dataSize))
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            // フェードアウトで自然な減衰
            let envelope = max(0, 1.0 - t / duration)
            let value = Int16(amplitude * envelope * sin(2.0 * .pi * frequency * t) * Double(Int16.max))
            withUnsafeBytes(of: value.littleEndian) { samples.append(contentsOf: $0) }
        }

        return header + samples
    }

    private func advancePhase() {
        if phase == .work {
            phase = .rest
            remainingSeconds = phase.duration
        } else {
            if currentSession < totalSessions {
                currentSession += 1
                phase = .work
                remainingSeconds = phase.duration
            } else {
                stop()
            }
        }
    }
}

// MARK: - Donut Progress View

struct DonutProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var model = PomodoroModel()
    @State private var showSessionPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // ドーナツグラフ + 中央テキスト
            ZStack {
                // 外側: 全体進捗
                DonutProgressView(
                    progress: model.overallProgress,
                    color: .secondary
                )
                .padding(4)

                // 内側: 現在フェーズ進捗
                DonutProgressView(
                    progress: model.progress,
                    color: model.ringColor
                )
                .padding(32)

                // 中央テキスト
                VStack(spacing: 8) {
                    if model.isRunning {
                        Text(model.phase.label)
                            .font(.headline)
                            .foregroundStyle(model.ringColor)

                        Text(String(format: "%02d:%02d", model.minutesDisplay, model.secondsDisplay))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())

                        Text(model.sessionSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("ポモドーロ")
                            .font(.title2.bold())
                        Text("タイマー")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 300, maxHeight: 300)

            Spacer()

            // 開始 / 停止ボタン
            Button {
                if model.isRunning {
                    model.stop()
                } else {
                    showSessionPicker = true
                }
            } label: {
                Text(model.isRunning ? "停止" : "開始")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isRunning ? .red : .accentColor)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .confirmationDialog("セッション数を選択", isPresented: $showSessionPicker, titleVisibility: .visible) {
            ForEach(1...5, id: \.self) { count in
                Button("\(count) セッション（\(count * 30)分）") {
                    model.start(sessions: count)
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}

#Preview {
    ContentView()
}
