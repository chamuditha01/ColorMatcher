//
//  TutorialView.swift
//  ColorMatcher
//
//  Created by COBSCCOMP242P-009 on 2026-01-24.
//

import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @State private var step = 0
    @State private var card1Flipped = false
    @State private var card2Flipped = false
    @State private var showMatchSuccess = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Tutorial Header
            HStack {
                Text("How to Play")
                    .font(.largeTitle.bold())
                Spacer()
                Button("Skip") { dismiss() }
                    .foregroundColor(.secondary)
            }
            .padding()

            Spacer()

            // Interactive Area
            VStack(spacing: 20) {
                Text(tutorialSteps[step].instruction)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .id(step) // Triggers animation on change
                    .transition(.opacity)

                HStack(spacing: 20) {
                    TutorialCard(isOpen: card1Flipped, color: .orange)
                        .onTapGesture { handleTap(1) }
                    
                    TutorialCard(isOpen: card2Flipped, color: .orange)
                        .onTapGesture { handleTap(2) }
                }
                .frame(height: 150)
            }

            Spacer()

            // Progress Indicator
            HStack {
                ForEach(0..<tutorialSteps.count, id: \.self) { i in
                    Circle()
                        .fill(i == step ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.bottom)

            Button(action: nextStep) {
                Text(step == tutorialSteps.count - 1 ? "Got it!" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .disabled(!canProceed)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }

    private var canProceed: Bool {
        if step == 0 && !card1Flipped { return false }
        if step == 1 && !card2Flipped { return false }
        return true
    }

    private func handleTap(_ card: Int) {
        withAnimation(.spring()) {
            if step == 0 && card == 1 {
                card1Flipped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { nextStep() }
            } else if step == 1 && card == 2 {
                card2Flipped = true
                showMatchSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { nextStep() }
            }
        }
    }

    private func nextStep() {
        if step < tutorialSteps.count - 1 {
            withAnimation { step += 1 }
        } else {
            dismiss()
        }
    }

    private let tutorialSteps: [(instruction: String, id: Int)] = [
        ("Tap the first card to reveal its color.", 0),
        ("Now find its match! Tap the second card.", 1),
        ("Great! Matches clear the board and increase your score.", 2),
        ("Be fast! Levels get harder and the timer gets shorter automatically.", 3)
    ]
}

struct TutorialCard: View {
    var isOpen: Bool
    var color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(isOpen ? color : Color.blue)
            .overlay(
                Image(systemName: "questionmark")
                    .font(.largeTitle)
                    .foregroundColor(.white.opacity(isOpen ? 0 : 1))
            )
            .shadow(radius: 5)
            .rotation3DEffect(.degrees(isOpen ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }
}
