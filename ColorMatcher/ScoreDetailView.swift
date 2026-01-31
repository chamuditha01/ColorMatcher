//
//  ScoreDetailView.swift
//  ColorMatcher
//
//  Created by COBSCCOMP242P-009 on 2026-01-24.
//

import SwiftUI

import SwiftUI

struct ScoreDetailView: View {
    @EnvironmentObject var scoreManager: ScoreManager
    
    // Sort users by their high score for the leaderboard
    var sortedUsers: [User] {
        scoreManager.users.sorted(by: { $0.highScore > $1.highScore })
    }
    
    var body: some View {
        List {
            if sortedUsers.isEmpty {
                Text("No scores recorded yet.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(sortedUsers.enumerated()), id: \.element.id) { index, user in
                    HStack(spacing: 15) {
                        // Rank Number
                        Text("\(index + 1)")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(index == 0 ? .orange : .secondary)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(user.name)
                                .font(.headline)
                            Text("\(user.gamesPlayed) sessions played")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // User's high score
                        VStack(alignment: .trailing) {
                            Text("\(user.highScore)")
                                .font(.title3.bold())
                                .foregroundColor(.blue)
                            Text("Best")
                                .font(.system(size: 10).bold())
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Global Rankings")
    }
}
