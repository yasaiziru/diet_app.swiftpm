import SwiftUI

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

    private var timerTask: Task<Void, Never>?

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
                if remainingSeconds > 0 {
                    remainingSeconds -= 1
                } else {
                    advancePhase()
                }
            }
        }
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
                    color: model.phase.color
                )
                .padding(32)

                // 中央テキスト
                VStack(spacing: 8) {
                    if model.isRunning {
                        Text(model.phase.label)
                            .font(.headline)
                            .foregroundStyle(model.phase.color)

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
