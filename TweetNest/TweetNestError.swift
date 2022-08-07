//
//  TweetNestError.swift
//  TweetNestError
//
//  Created by Jaehong Kang on 2021/08/16.
//

import Foundation
import SwiftUI
import Twitter

struct TweetNestError {
    var error: Error?
    var kind: Kind

    init(_ error: Error? = nil, kind: Kind = .unknown) {
        self.error = error
        self.kind = kind
    }
}

extension TweetNestError {
    enum Kind {
        case unknown
    }
}

extension TweetNestError: LocalizedError {
    var errorDescription: String? {
        error?.localizedDescription
    }

    var failureReason: String? {
        (error as? LocalizedError)?.failureReason
    }
}

extension TweetNestError: RecoverableError {
    var recoveryOptions: [String] {
        return []
    }

    func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool {
        return false
    }
}

extension View {
    @ViewBuilder
    func alert(isPresented: Binding<Bool>, error: TweetNestError?, onDismiss: ((TweetNestError) -> Void)? = nil) -> some View {
        self.alert(isPresented: isPresented, error: error) { error in
            Button(role: .cancel) {
                onDismiss?(error)
            } label: {
                Text("OK")
            }
        } message: { error in
            if let failureReason = error.failureReason {
                Text(failureReason)
            }
        }
    }
}
