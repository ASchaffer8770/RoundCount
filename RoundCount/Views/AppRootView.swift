//
//  AppRootView.swift
//  RoundCount
//
//  Created by Alex Schaffer on 1/16/26.
//

import SwiftUI

enum AppPhase {
    case splash
    case main
}

struct AppRootView: View {
    @State private var phase: AppPhase = .splash

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .main:
                RootTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: phase)
        .task {
            // Timed splash for now.
            // Later: await entitlement/data bootstrap here.
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            phase = .main
        }
    }
}
