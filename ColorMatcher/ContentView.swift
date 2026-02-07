import SwiftUI
import Combine
import FirebaseFirestore // Make sure this is imported

struct User: Identifiable, Codable, Equatable {
    @DocumentID var id: String?  // This is the magic fix
    var name: String
    var highScore: Int = 0
    var totalPoints: Int = 0
    var gamesPlayed: Int = 0

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case highScore
        case totalPoints
        case gamesPlayed
    }
}
struct Square: Identifiable {
    let id = UUID()
    let color: Color
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// MARK: - Score Manager (Firebase Logic)
class ScoreManager: ObservableObject {
    @Published var users: [User] = []
    @Published var currentUserIndex: Int? = nil
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    var currentUser: User? {
        guard let index = currentUserIndex, users.indices.contains(index) else { return nil }
        return users[index]
    }

    init() {
        // Force Firestore to connect to the network
        db.enableNetwork { error in
            if let error = error {
                print("Could not enable network: \(error.localizedDescription)")
            } else {
                print("Firestore Network Enabled")
            }
        }
        fetchUsers()
    }

    /// Fetches all users from Firestore in real-time
    func fetchUsers() {
        listener = db.collection("users")
            .order(by: "highScore", descending: true)
            .addSnapshotListener { (querySnapshot, error) in
                guard let documents = querySnapshot?.documents else {
                    print("Firebase Error: \(error?.localizedDescription ?? "Unknown")")
                    return
                }
                
                DispatchQueue.main.async {
                    self.users = documents.compactMap { doc -> User? in
                        do {
                            // This will now tell us EXACTLY what is wrong in the Xcode console
                            return try doc.data(as: User.self)
                        } catch {
                            print("Decoding Error for doc \(doc.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    if !self.users.isEmpty && self.currentUserIndex == nil {
                        self.currentUserIndex = 0
                    }
                }
            }
    }

    func addUser(name: String) {
        let newId = UUID().uuidString
        let userRef = db.collection("users").document(newId)
        
        // Manual dictionary ensures Firebase sees exactly what we want to send
        let userData: [String: Any] = [
            "id": newId,
            "name": name,
            "highScore": 0,
            "totalPoints": 0,
            "gamesPlayed": 0
        ]
        
        userRef.setData(userData) { error in
            if let error = error {
                print("❌ Firebase Write Failed: \(error.localizedDescription)")
            } else {
                print("✅ Successfully saved to Cloud Firestore! ID: \(newId)")
            }
        }
    }

    func updateScore(newScore: Int) {
        guard let user = currentUser, newScore > 0 else { return }
        
        let userRef = db.collection("users").document(user.id ?? <#default value#>)
        let isNewHighScore = newScore > user.highScore
        
        userRef.updateData([
            "totalPoints": FieldValue.increment(Int64(newScore)),
            "gamesPlayed": FieldValue.increment(Int64(1)),
            "highScore": isNewHighScore ? newScore : user.highScore
        ])
    }
    
    deinit {
        listener?.remove()
    }
}

// MARK: - Dashboard
struct ContentView: View {
    @StateObject var scoreManager = ScoreManager()
    @State private var showingUserPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Button(action: { showingUserPicker = true }) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").font(.title)
                        VStack(alignment: .leading) {
                            Text("Current Player").font(.caption)
                            Text(scoreManager.currentUser?.name ?? "Select User").font(.headline)
                        }
                        Spacer()
                        Image(systemName: "arrow.left.and.right.circle")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile").font(.system(size: 60)).foregroundColor(.blue)
                    Text("Memory Master").font(.system(.largeTitle, design: .rounded)).bold()
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    NavigationLink(destination: GameView().environmentObject(scoreManager)) {
                        MenuButton(title: "Start Infinite Run", icon: "play.fill", color: .blue)
                    }
                    NavigationLink(destination: ScoreDetailView().environmentObject(scoreManager)) {
                        MenuButton(title: "Leaderboard", icon: "chart.bar.xaxis", color: .secondary)
                    }
                    NavigationLink(destination: TutorialView()) {
                        MenuButton(title: "How to Play", icon: "questionmark.circle", color: .orange)
                    }
                }
                // Inside ContentView body...
                VStack(alignment: .leading) {
                    Text("Current Player").font(.caption)
                    if let user = scoreManager.currentUser {
                        Text(user.name).font(.headline)
                    } else if scoreManager.users.isEmpty {
                        Text("Loading Players...").font(.headline).italic() // Shows while Firebase is thinking
                    } else {
                        Text("Select User").font(.headline)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                HStack(spacing: 40) {
                    VStack {
                        Text("\(scoreManager.currentUser?.highScore ?? 0)").font(.headline)
                        Text("Best").font(.caption).foregroundColor(.secondary)
                    }
                    VStack {
                        Text("\(scoreManager.currentUser?.gamesPlayed ?? 0)").font(.headline)
                        Text("Runs").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Dashboard")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingUserPicker) { UserSelectionView(scoreManager: scoreManager) }
        }
    }
}

// MARK: - Game View
struct GameView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var scoreManager: ScoreManager
    
    @State private var currentLevel: Int = 1
    @State private var score: Int = 0
    @State private var streak: Int = 0
    @State private var grid: [Square] = []
    @State private var selectedIndices: [Int] = []
    @State private var isGameLocked: Bool = false
    @State private var timeRemaining = 15
    @State private var timerActive = false
    @State private var showGameOver = false
    @State private var hasSaved = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let allColors: [Color] = [.red, .green, .blue, .orange, .purple, .pink, .yellow, .cyan, .brown, .indigo, .mint, .teal, .gray]

    var columns: [GridItem] {
        let count = currentLevel < 3 ? 3 : (currentLevel < 6 ? 4 : 5)
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading) {
                    Text("PLAYER: \(scoreManager.currentUser?.name ?? "Guest")").font(.caption2).foregroundColor(.secondary)
                    Text("LEVEL \(currentLevel)").font(.caption.bold()).foregroundColor(.blue)
                    Text("Score: \(score)").font(.title3.bold())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Streak x\(streak)").foregroundColor(streak > 1 ? .orange : .secondary).bold()
                    Text("\(timeRemaining)s").font(.title3.monospacedDigit().bold())
                        .foregroundColor(timeRemaining < 5 ? .red : .primary)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)).shadow(radius: 2))
            .padding(.horizontal)

            GeometryReader { _ in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(0..<grid.count, id: \.self) { index in
                            ZStack {
                                if !grid[index].isMatched {
                                    CardView(square: grid[index])
                                        .onTapGesture { handleTap(at: index) }
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Color.clear.aspectRatio(1, contentMode: .fit)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }

            Button(role: .destructive, action: { saveScore(); dismiss() }) {
                Text("Quit Session").fontWeight(.semibold).padding()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: setupLevel)
        .onDisappear(perform: saveScore)
        .onReceive(timer) { _ in
            if timerActive && timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining == 0 { endGame() }
            }
        }
        .alert("Game Over", isPresented: $showGameOver) {
            Button("Main Menu") { dismiss() }
        } message: { Text("Final Score: \(score)") }
    }
    
    func saveScore() {
        guard !hasSaved else { return }
        scoreManager.updateScore(newScore: score)
        hasSaved = true
    }

    func setupLevel() {
        isGameLocked = true
        timerActive = false
        selectedIndices = []
        let numberOfPairs = min(currentLevel + 2, 12)
        var levelColors: [Color] = []
        for i in 0..<numberOfPairs { levelColors.append(allColors[i % allColors.count]) }
        var newGrid: [Square] = []
        for color in levelColors {
            newGrid.append(Square(color: color, isFaceUp: true))
            newGrid.append(Square(color: color, isFaceUp: true))
        }
        grid = newGrid.shuffled()
        timeRemaining = 10 + (numberOfPairs * 2)
        let previewTime = max(2.0 - (Double(currentLevel) * 0.1), 0.5)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + previewTime) {
            withAnimation(.spring()) {
                for i in 0..<grid.count { grid[i].isFaceUp = false }
            }
            isGameLocked = false
            timerActive = true
        }
    }

    func handleTap(at index: Int) {
        guard !isGameLocked, timerActive, !grid[index].isMatched, !grid[index].isFaceUp, selectedIndices.count < 2 else { return }
        withAnimation(.easeInOut(duration: 0.3)) { grid[index].isFaceUp = true }
        selectedIndices.append(index)
        if selectedIndices.count == 2 { checkMatch() }
    }

    func checkMatch() {
        let first = selectedIndices[0], second = selectedIndices[1]
        if grid[first].color == grid[second].color {
            streak += 1
            score += (10 * streak) * currentLevel
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring()) {
                    grid[first].isMatched = true
                    grid[second].isMatched = true
                    selectedIndices = []
                }
                if grid.allSatisfy({ $0.isMatched }) { nextLevel() }
            }
        } else {
            streak = 0
            isGameLocked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation {
                    grid[first].isFaceUp = false
                    grid[second].isFaceUp = false
                    selectedIndices = []
                    isGameLocked = false
                }
            }
        }
    }

    func nextLevel() {
        timerActive = false
        score += timeRemaining * 5
        currentLevel += 1
        setupLevel()
    }

    func endGame() {
        timerActive = false
        saveScore()
        showGameOver = true
    }
}

// MARK: - User Selection View
struct UserSelectionView: View {
    @ObservedObject var scoreManager: ScoreManager
    @Environment(\.dismiss) var dismiss
    @State private var newUserName = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Switch Profile") {
                    ForEach(0..<scoreManager.users.count, id: \.self) { index in
                        Button(action: {
                            scoreManager.currentUserIndex = index
                            dismiss()
                        }) {
                            HStack {
                                Text(scoreManager.users[index].name).foregroundColor(.primary)
                                Spacer()
                                if scoreManager.currentUserIndex == index {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                Section("New Player") {
                    HStack {
                        TextField("Enter Name", text: $newUserName)
                        Button("Add") {
                            if !newUserName.isEmpty {
                                scoreManager.addUser(name: newUserName)
                                newUserName = ""
                            }
                        }
                        .disabled(newUserName.isEmpty)
                    }
                }
            }
            .navigationTitle("Profiles")
        }
    }
}



// MARK: - Reuse Components
struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(color == .blue ? 1.0 : 0.1))
            .foregroundColor(color == .blue ? .white : color)
            .cornerRadius(15)
    }
}

struct CardView: View {
    let square: Square
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.blue, .blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Image(systemName: "questionmark").foregroundColor(.white.opacity(0.6)))
                .opacity(square.isFaceUp ? 0 : 1)
            
            RoundedRectangle(cornerRadius: 12)
                .fill(square.color)
                .opacity(square.isFaceUp ? 1 : 0)
        }
        .rotation3DEffect(.degrees(square.isFaceUp ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: square.isFaceUp)
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ContentView()
}
