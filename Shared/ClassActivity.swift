import ActivityKit
import Foundation

struct ClassActivity: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date
        var end: Date
        var launched: Date
    }
    var title: String
    var room: String
    var isDemo: Bool
}
