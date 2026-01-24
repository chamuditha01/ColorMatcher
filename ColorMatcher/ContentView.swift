import SwiftUI
import Combine

struct Square: Identifiable {
    let id = UUID()
    let color: Color
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// MARK: - Dashboard
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text("Memory Master")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .padding(.bottom, 0)
                Text("Color Matcher")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .padding(.bottom, 20)
                // Option 1: Direct Start (Level 1)
                NavigationLink(destination: GameView(initialLevel: 1)) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start New Game")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                // Option 2: Select Levels
                NavigationLink(destination: LevelSelectionView()) {
                    HStack {
                        Image(systemName: "layers.fill")
                        Text("Select Level")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 40)
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - Level Selection
struct LevelSelectionView: View {
    let levels = 1...5
    
    var body: some View {
        List(levels, id: \.self) { level in
            NavigationLink(destination: GameView(initialLevel: level)) {
                HStack(spacing: 15) {
                    Text("\(level)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 35, height: 35)
                        .background(Color.blue)
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text("Level \(level)")
                            .font(.body.bold())
                        Text("\(level * 3) Pairs to find")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Choose a Level")
    }
}

// MARK: - Game View
struct GameView: View {
    @Environment(\.dismiss) var dismiss
    
    let initialLevel: Int
    @State private var currentLevel: Int
    
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
        .mint, .teal, .gray, .black, Color(red: 1, green: 0, blue: 1)
    ]

    init(initialLevel: Int) {
        self.initialLevel = initialLevel
        _currentLevel = State(initialValue: initialLevel)
    }

    var columns: [GridItem] {
        let count = currentLevel > 2 ? 4 : 3
        return Array(repeating: GridItem(.flexible()), count: count)
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("LEVEL \(currentLevel)")
                        .font(.caption.bold())
                        .foregroundColor(.blue)
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

            Button("Quit Game") {
                dismiss()
            }
            .foregroundColor(.red)
            .padding(.bottom)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: setupGame)
        .onReceive(timer) { _ in
            if timerActive && timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining == 0 { endGame(success: false) }
            }
        }
        .alert(gameSuccess ? "Level Complete!" : "Game Over", isPresented: $showGameOver) {
            if gameSuccess {
                if currentLevel < 5 {
                    Button("Next Level") {
                        currentLevel += 1
                        setupGame()
                    }
                } else {
                    Button("Finish") { dismiss() }
                }
            } else {
                Button("Try Again") { setupGame() }
                Button("Quit", role: .cancel) { dismiss() }
            }
        } message: {
            Text(gameSuccess ? "Great job! Ready for level \(currentLevel + 1)?" : "You ran out of time.")
        }
    }

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

// MARK: - Card Component
struct CardView: View {
    let square: Square
    var body: some View {
        ZStack {
            if !square.isMatched {
                RoundedRectangle(cornerRadius: 12)
                    .fill(square.isFaceUp ? square.color : Color.blue.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )
                    .shadow(radius: 2)
                
                if !square.isFaceUp {
                    Image(systemName: "questionmark")
                        .foregroundColor(.white)
                        .font(.title.bold())
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.clear)
            }
        }
        .frame(height: 90)
    }
}

#Preview {
    ContentView()
}
