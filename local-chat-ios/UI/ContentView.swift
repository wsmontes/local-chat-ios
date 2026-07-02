import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RunTestView()
                .tabItem {
                    Label("Run Test", systemImage: "play.circle")
                }

            ResultsListView()
                .tabItem {
                    Label("Results", systemImage: "chart.bar")
                }

            ModelsListView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
        }
    }
}
