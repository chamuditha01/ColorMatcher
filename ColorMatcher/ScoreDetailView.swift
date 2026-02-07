import SwiftUI

struct ScoreDetailView: View {
    @EnvironmentObject var scoreManager: ScoreManager
    
    // Firebase already sends data sorted if you used .order(by: "highScore"),
    // but this ensures the UI stays consistent.
    var sortedUsers: [User] {
        scoreManager.users.sorted(by: { $0.highScore > $1.highScore })
    }
    
    var body: some View {
        List {
            if scoreManager.users.isEmpty {
                // Show a loading state while Firebase fetches data
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Fetching Global Rankings...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 40)
            } else {
                Section(header: Text("Top Players")) {
                    ForEach(Array(sortedUsers.enumerated()), id: \.element.id) { index, user in
                        HStack(spacing: 15) {
                            // Rank Badge Logic
                            RankBadge(rank: index + 1)
                            
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                    .foregroundColor(user.id == scoreManager.currentUser?.id ? .blue : .primary)
                                
                                Text("\(user.gamesPlayed) sessions played")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Score Display
                            VStack(alignment: .trailing) {
                                Text("\(user.highScore)")
                                    .font(.system(.title3, design: .rounded))
                                    .bold()
                                    .foregroundColor(.blue)
                                Text("Best")
                                    .font(.system(size: 10).bold())
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                        }
                        .padding(.vertical, 4)
                        // Highlight the current logged-in user
                        .listRowBackground(user.id == scoreManager.currentUser?.id ? Color.blue.opacity(0.05) : Color(.systemBackground))
                    }
                }
            }
        }
        .navigationTitle("Global Rankings")
        .refreshable {
            // Pull-to-refresh manually (optional, since SnapshotListener is real-time)
            scoreManager.fetchUsers()
        }
    }
}

// A small helper view for the Rank circles
struct RankBadge: View {
    let rank: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(rankColor(for: rank))
                .frame(width: 30, height: 30)
            
            Text("\(rank)")
                .font(.caption.bold())
                .foregroundColor(rank <= 3 ? .white : .primary)
        }
    }
    
    func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return .orange // Gold
        case 2: return .gray.opacity(0.5) // Silver
        case 3: return .brown.opacity(0.7) // Bronze
        default: return .clear
        }
    }
}
