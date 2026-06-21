import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundStyle(.pink)
            Text(AppInfo.displayName)
                .font(.headline)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
