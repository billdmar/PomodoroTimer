//
//  StarParticlesView.swift
//  pomadoro2
//
//  Created by Bill Mar on 7/30/25.
//

import SwiftUI

struct StarParticlesView: View {
    @State private var showStars = false
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Group {
                    if index % 3 == 0 {
                        Text("✨")
                            .font(.system(size: 16))
                    } else if index % 3 == 1 {
                        Text("⭐")
                            .font(.system(size: 14))
                    } else {
                        Text("💫")
                            .font(.system(size: 12))
                    }
                }
                .offset(starOffset(for: index))
                .opacity(showStars ? 0 : 1)
                .scaleEffect(showStars ? 2.0 : 0.3)
                .rotationEffect(.degrees(showStars ? 360 : 0))
                .animation(
                    .easeOut(duration: 2.5)
                    .delay(Double(index) * 0.1),
                    value: showStars
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showStars = true
            }
        }
    }
    
    private func starOffset(for index: Int) -> CGSize {
        let angle = Double(index) * .pi * 2 / 12
        let distance: CGFloat = CGFloat(100 + (index % 3) * 30)
        let x = cos(angle) * distance
        let y = sin(angle) * distance
        return CGSize(width: x, height: y)
    }
}
