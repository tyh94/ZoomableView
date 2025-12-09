//
//  ContentView.swift
//  Example
//
//  Created by Татьяна Макеева on 30.11.2025.
//

import SwiftUI
import ZoomableView

struct ContentView: View {
    var body: some View {
        GeometryReader { proxy in
            Image(.images)
            //            Image(.zebra)
                .resizable()
                .border(.blue)
                .zoomable(
                    containerSize: proxy.size,
                    logger: ConsoleLogger()
                )
        }
        .border(.red)
    }
}

struct ConsoleLogger: Logger {
    func log(_ message: String, level: ZoomableView.LogLevel, file: String, function: String, line: Int) {
        print(message)
    }
}

#Preview {
    ContentView()
}
