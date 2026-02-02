import SwiftUI

struct NumberEntry: Identifiable {
    let id = UUID()
    let value: Int
    let color: Color

    static func random() -> NumberEntry {
        NumberEntry(
            value: Int.random(in: 1...9999),
            color: Color(
                hue: Double.random(in: 0...1),
                saturation: Double.random(in: 0.5...1.0),
                brightness: Double.random(in: 0.6...1.0)
            )
        )
    }
}

struct ContentView: View {
    @State private var current: NumberEntry?
    @State private var history: [NumberEntry] = []

    var body: some View {
        VStack {
            Spacer()

            // 履歴（古い順＝上ほど薄い）
            ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                let opacity = 0.15 + 0.85 * Double(index) / max(Double(history.count), 1)
                Text("\(entry.value)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.color.opacity(opacity))
            }

            // 現在の数字
            if let current {
                Text("\(current.value)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(current.color)
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                if let current {
                    history.append(current)
                    if history.count > 5 {
                        history.removeFirst()
                    }
                }
                withAnimation {
                    current = NumberEntry.random()
                }
            } label: {
                Text("ダイスを振る")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    ContentView()
}
