import SwiftUI
import Combine

struct Square: Identifiable {
    let id = UUID()
    let color: Color
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("Memory Master")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                
                NavigationLink(destination: GameView()) {
                    Label("Start New Game", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 50)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct GameView: View {
    // --- 1. Navigation Control ---
    @Environment(\.dismiss) var dismiss
    
    // --- Level State ---
    @State private var currentLevel = 1
    let maxLevel = 5
    
    // --- Game Logic State ---
    @State private var grid: [Square] = []
    @State private var selectedIndices: [Int] = []
    @State private var isGameLocked: Bool = false
    @State private var timeRemaining = 30
    @State private var timerActive = false
    @State private var showGameOver = false
    @State private var gameSuccess = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let allColors: [Color] = [
        .red, .green, .blue, .orange, .purple,
        .pink, .yellow, .cyan, .brown, .indigo,
        .mint, .teal, .gray, .black,
        Color(red: 1, green: 0, blue: 1)
    ]

    var columns: [GridItem] {
        let count = currentLevel > 2 ? 4 : 3
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Level \(currentLevel)")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("Time: \(timeRemaining)s")
                        .font(.title2.monospacedDigit().bold())
                        .foregroundColor(timeRemaining < 10 ? .red : .primary)
                }
                Spacer()
                Text("\(grid.filter { $0.isMatched }.count / 2) / \(grid.count / 2) Pairs")
                    .font(.subheadline.bold())
            }
            .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<grid.count, id: \.self) { index in
                        CardView(square: grid[index])
                            .onTapGesture {
                                if !isGameLocked && timerActive { handleTap(at: index) }
                            }
                    }
                }
                .padding()
            }

            // --- 2. Quit Game Fix ---
            Button("Quit Game") {
                dismiss() // This pops the view back to Dashboard
            }
            .foregroundColor(.red)
            .padding(.bottom)
        }
        .navigationTitle("Level \(currentLevel)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Forces use of Quit button
        .onAppear(perform: { setupGame() })
        .onReceive(timer) { _ in
            if timerActive && timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining == 0 { endGame(success: false) }
            }
        }
        // --- 3. Alert Button Logic ---
        .alert(gameSuccess ? "Level Complete!" : "Game Over", isPresented: $showGameOver) {
            if gameSuccess {
                if currentLevel < maxLevel {
                    Button("Next Level") {
                        currentLevel += 1
                        setupGame()
                    }
                } else {
                    Button("Finish") {
                        dismiss()
                    }
                }
            } else {
                Button("Try Again") { setupGame() }
                Button("Quit", role: .cancel) {
                    dismiss()
                }
            }
        } message: {
            Text(gameSuccess ? "Great job! Ready for level \(currentLevel + 1)?" : "You ran out of time.")
        }
    }

    // Logic remains same
    func setupGame() {
        isGameLocked = true
        timerActive = false
        selectedIndices = []
        let numberOfPairs = currentLevel * 3
        let levelColors = Array(allColors.shuffled().prefix(numberOfPairs))
        var newGrid: [Square] = []
        for color in levelColors {
            newGrid.append(Square(color: color, isFaceUp: true))
            newGrid.append(Square(color: color, isFaceUp: true))
        }
        grid = newGrid.shuffled()
        timeRemaining = 20 + (currentLevel * 10)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring()) {
                for i in 0..<grid.count { grid[i].isFaceUp = false }
            }
            isGameLocked = false
            timerActive = true
        }
    }

    func handleTap(at index: Int) {
        if grid[index].isMatched || grid[index].isFaceUp || selectedIndices.count >= 2 { return }
        withAnimation(.easeInOut(duration: 0.3)) { grid[index].isFaceUp = true }
        selectedIndices.append(index)
        if selectedIndices.count == 2 { checkMatch() }
    }

    func checkMatch() {
        let first = selectedIndices[0], second = selectedIndices[1]
        if grid[first].color == grid[second].color {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    grid[first].isMatched = true
                    grid[second].isMatched = true
                    selectedIndices = []
                }
                if grid.allSatisfy({ $0.isMatched }) { endGame(success: true) }
            }
        } else {
            isGameLocked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    grid[first].isFaceUp = false
                    grid[second].isFaceUp = false
                    selectedIndices = []
                    isGameLocked = false
                }
            }
        }
    }

    func endGame(success: Bool) {
        timerActive = false
        gameSuccess = success
        showGameOver = true
    }
}

struct CardView: View {
    let square: Square
    var body: some View {
        ZStack {
            if !square.isMatched {
                RoundedRectangle(cornerRadius: 12)
                    .fill(square.isFaceUp ? square.color : Color.blue.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    .shadow(radius: 2)
                if !square.isFaceUp {
                    Image(systemName: "questionmark").foregroundColor(.white).font(.title.bold())
                }
            } else {
                RoundedRectangle(cornerRadius: 12).fill(Color.clear)
            }
        }
        .frame(height: 90)
    }
}
#Preview {
    ContentView()
}
