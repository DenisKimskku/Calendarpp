//
//  ContentView.swift
//  calendar++
//
//  Created by den on 12/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .imageScale(.large)
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Calendar++")
                .font(.title)
                .fontWeight(.semibold)

            Text("Your menu bar calendar is running!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Look for the calendar icon in your menu bar.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

#Preview {
    ContentView()
}
