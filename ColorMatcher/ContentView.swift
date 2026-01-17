import SwiftUI

// --- Model remains the same ---
struct Square: Identifiable {
    let id = UUID()
    let color: Color
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// 2. The Main Dashboard View
struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "square.grid.3x3.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                
                Text("Memory Matcher")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                
                VStack(spacing: 15) {
                    // Navigation Link to the Game
                    NavigationLink(destination: GameView()) {
                        Label("Start New Game", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    
                    // Example of another dashboard button
                    Button(action: { /* Add settings or high scores logic here */ }) {
                        Label("High Scores", systemImage: "trophy.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 60)
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}

// 3. The Game View (Moved your original logic here)
struct GameView: View {
    @State private var grid: [Square] = []
    @State private var selectedIndices: [Int] = []
    @State private var isGameLocked: Bool = false
    
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let colors: [Color] = [.red, .green, .blue]

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(0..<grid.count, id: \.self) { index in
                    ZStack {
                        if !grid[index].isMatched {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(grid[index].isFaceUp ? grid[index].color : Color.gray)
                                .frame(height: 100)
                                .onTapGesture {
                                    if !isGameLocked { handleTap(at: index) }
                                }
                                .rotation3DEffect(
                                    .degrees(grid[index].isFaceUp ? 180 : 0),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                        } else {
                            Spacer().frame(height: 100)
                        }
                    }
                }
            }
            .padding()

            Button("Restart Game") {
                setupGame()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isGameLocked)
        }
        .navigationTitle("Matching Game")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setupGame)
    }

    // --- Original Game Logic Functions (setupGame, handleTap, checkMatch) ---
    func setupGame() {
        var newGrid: [Square] = []
        for color in colors {
            newGrid.append(Square(color: color, isFaceUp: true))
            newGrid.append(Square(color: color, isFaceUp: true))
            newGrid.append(Square(color: color, isFaceUp: true))
        }
        grid = newGrid.shuffled()
        selectedIndices = []
        isGameLocked = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                for i in 0..<grid.count { grid[i].isFaceUp = false }
            }
            isGameLocked = false
        }
    }

    func handleTap(at index: Int) {
        if isGameLocked || grid[index].isMatched || grid[index].isFaceUp || selectedIndices.count == 2 { return }
        withAnimation(.linear(duration: 0.3)) { grid[index].isFaceUp = true }
        selectedIndices.append(index)
        if selectedIndices.count == 2 { checkMatch() }
    }

    func checkMatch() {
        let firstIndex = selectedIndices[0]
        let secondIndex = selectedIndices[1]

        if grid[firstIndex].color == grid[secondIndex].color {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    grid[firstIndex].isMatched = true
                    grid[secondIndex].isMatched = true
                    selectedIndices = []
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    grid[firstIndex].isFaceUp = false
                    grid[secondIndex].isFaceUp = false
                    selectedIndices = []
                }
            }
        }
    }
}
#Preview {
    ContentView()
}
