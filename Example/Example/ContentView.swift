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
            BounceZoomableView(
                containerSize: proxy.size,
                focusPoint: .constant(nil)
            ) {
                Image(.zebra)
                    .resizable()
                    .border(.blue)
            }
        }
        .border(.red)
    }
}

#Preview {
    ContentView()
}
