//
//  DeleteBulkTweetsRecentTweetsView.swift
//  DeleteBulkTweetsRecentTweetsView
//
//  Created by Jaehong Kang on 2021/08/15.
//

import SwiftUI
import TweetNestKit
import Twitter

struct DeleteBulkTweetsRecentTweetsView: View {
    @Environment(\.session) private var session: TweetNestKit.Session

    let account: TweetNestKit.Account

    @Binding var isPresented: Bool

    @State var tweets: [Tweet]?

    @State var showError: Bool = false
    @State var error: TweetNestError?

    var body: some View {
        ZStack {
            if let tweets = tweets {
                DeleteBulkTweetsFormView(tweets: tweets, isPresented: $isPresented)
                    .environment(\.account, account)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                ProgressView("Loading Recent Tweets...")
                    .task {
                        await fetchTweets()
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                isPresented = false
                            } label: {
                                Text("Cancel")
                            }
                        }
                    }
                    .alert(isPresented: $showError, error: error)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle(Text("Delete Tweets"))
    }

    func fetchTweets() async {
        guard let userID = account.userID else {
            return
        }

        do {
            let tweets = try await User.tweets(forUserID: userID, session: .session(for: account, session: session))
                .map { try $0.get() }

            withAnimation {
                self.tweets = tweets
            }
        } catch {
            self.error = TweetNestError(error)
            showError = true
        }
    }
}

struct DeleteBulkTweetsRecentTweetsView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteBulkTweetsRecentTweetsView(account: .preview, isPresented: .constant(true))
    }
}
