//
//  ContentView.swift
//  NarrativeDemo
//
//  Created by Stephen Sweeney on 1/2/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("SwiftVector Narrative Demo")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(vm.state.currentScene)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(8)
                
                Button(vm.state.isGameOver ? "Game Over" : "What happens next?") {
                    vm.nextEvent()
                }
                .buttonStyle(.borderedProminent)
                .font(.title3)
                .disabled(vm.state.isGameOver)
                
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.narrativeLog, id: \.self) { event in
                            Text(event)
                                .font(.subheadline)
                                .padding(.horizontal)
                                .padding(.vertical, event.hasPrefix("🛡️") ? 4 : 0)
                                .background(
                                    event.hasPrefix("🛡️")
                                        ? Color.orange.opacity(0.12)
                                        : Color.clear
                                )
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Adventure")
        }
    }
}

#Preview {
    ContentView()
}
