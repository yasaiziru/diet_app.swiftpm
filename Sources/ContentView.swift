import SwiftUI

struct ContentView: View {
    @State private var currentNumber: Int?
    @State private var history: [Int] = []

    var body: some View {
        VStack {
            Spacer()

            // 履歴（古い順＝上ほど薄い）
            ForEach(Array(history.enumerated()), id: \.offset) { index, number in
                let opacity = 0.15 + 0.85 * Double(index) / max(Double(history.count), 1)
                Text("\(number)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary.opacity(opacity))
            }

            // 現在の数字
            if let currentNumber {
                Text("\(currentNumber)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
            }

            Spacer()

            Button {
                if let currentNumber {
                    history.append(currentNumber)
                    if history.count > 5 {
                        history.removeFirst()
                    }
                }
                withAnimation {
                    currentNumber = Int.random(in: 1...6)
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
