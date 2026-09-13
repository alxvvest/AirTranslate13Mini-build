import Foundation

struct ConversationLine: Identifiable, Equatable {
    let id = UUID()
    let spanish: String
    let english: String
    let createdAt: Date
}
