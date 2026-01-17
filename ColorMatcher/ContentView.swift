import SwiftUI
internal import Combine

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
                Image(systemName: "timer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("Memory sss")
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
    @State private var grid: [Square] = []
    @State private var selectedIndices: [Int] = []
    @State private var isGameLocked: Bool = false
    
    // --- Timer & State Stats ---
    @State private var timeRemaining = 30 // 30 seconds limit
    @State private var timerActive = false
    @State private var showGameOver = false
    @State private var gameOverMessage = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let colors: [Color] = [.red, .green, .blue]

    var body: some View {
        VStack(spacing: 20) {
            // Timer Display
            HStack {
                Image(systemName: "clock")
                Text("Time Left: \(timeRemaining)s")
                    .font(.title2.monospacedDigit().bold())
                    .foregroundColor(timeRemaining < 10 ? .red : .primary)
            }
            .padding()

            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(0..<grid.count, id: \.self) { index in
                    ZStack {
                        if !grid[index].isMatched {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(grid[index].isFaceUp ? grid[index].color : Color.gray)
                                .frame(height: 100)
                                .onTapGesture {
                                    if !isGameLocked && timerActive { handleTap(at: index) }
                                }
                        } else {
                            // Empty space once matched
                            Color.clear.frame(height: 100)
                        }
                    }
                }
            }
            .padding()

            Button("Quit Game") {
                timeRemaining = 0
            }
            .foregroundColor(.red)
        }
        .navigationTitle("Matching Game")
        .onAppear(perform: setupGame)
        .onReceive(timer) { _ in
            if timerActive && timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining == 0 {
                    endGame(success: false)
                }
            }
        }
        .alert(gameOverMessage, isPresented:  $showGameOver) {
            Button("Back to Dashboard", role: .cancel) { /* Pop handled by NavStack */ }
            Button("Try Again") { setupGame() }
        }
    }

    func setupGame() {
        var newGrid: [Square] = []
        // We add 3 squares per color (Total 9).
        // Logic: 4 pairs will match, 1 square will remain.
        for color in colors {
            newGrid.append(Square(color: color, isFaceUp: true))
            newGrid.append(Square(color: color, isFaceUp: true))
            newGrid.append(Square(color: color, isFaceUp: true))
        }
        grid = newGrid.shuffled()
        selectedIndices = []
        timeRemaining = 30
        isGameLocked = true
        timerActive = false // Don't start clock during peek
        
        // Initial Peek
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                for i in 0..<grid.count { grid[i].isFaceUp = false }
            }
            isGameLocked = false
            timerActive = true // Start clock after peek
        }
    }

    func handleTap(at index: Int) {
        if isGameLocked || grid[index].isMatched || grid[index].isFaceUp || selectedIndices.count == 2 { return }
        
        withAnimation(.linear(duration: 0.3)) { grid[index].isFaceUp = true }
        selectedIndices.append(index)
        
        if selectedIndices.count == 2 {
            checkMatch()
        }
    }

    func checkMatch() {
        let first = selectedIndices[0]
        let second = selectedIndices[1]

        if grid[first].color == grid[second].color {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    grid[first].isMatched = true
                    grid[second].isMatched = true
                    selectedIndices = []
                }
                checkWinCondition()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    grid[first].isFaceUp = false
                    grid[second].isFaceUp = false
                    selectedIndices = []
                }
            }
        }
    }

    func checkWinCondition() {
        // Count how many squares are NOT matched
        let unmatchedCount = grid.filter { !$0.isMatched }.count
        
        // If only 1 square remains, you win!
        if unmatchedCount == 1 {
            endGame(success: true)
        }
    }

    func endGame(success: Bool) {
        timerActive = false
        gameOverMessage = success ? "Congratulations! You won!" : "Time's up! You failed."
        showGameOver = true
    }
}
#Preview {
    ContentView()
}
