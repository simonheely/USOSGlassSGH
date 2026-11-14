import ActivityKit
import WidgetKit
import SwiftUI

@main
struct CampusWidgets: WidgetBundle {
    var body: some Widget { CampusLiveActivity() }
}
struct CampusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivity.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "graduationcap.fill").font(.title).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 6) {
                    Text(context.attributes.isDemo ? "SGH · DEMO" : "SGH · ZAJĘCIA").font(.caption2.bold()).foregroundStyle(.secondary)
                    Text(context.attributes.title).font(.headline).lineLimit(2)
                    Text(context.attributes.room.isEmpty ? "Sala niepodana" : "Sala \(context.attributes.room)").font(.subheadline)
                }
                Spacer(minLength: 4)
                countdown(context).font(.title3.monospacedDigit().bold()).frame(maxWidth: 100)
            }
            .padding(20)
            .activityBackgroundTint(Color(red: 0.05, green: 0.14, blue: 0.17))
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "usosglass://today"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.isDemo ? "DEMO" : "SGH", systemImage: "graduationcap.fill")
                        .font(.caption.bold()).foregroundStyle(.mint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.room.isEmpty ? "Zajęcia" : "Sala \(context.attributes.room)").font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title).font(.headline).lineLimit(2).multilineTextAlignment(.center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.isStale ? "Zakończone" : "Do końca zajęć").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        countdown(context).font(.headline.monospacedDigit()).frame(maxWidth: 100)
                    }.padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: context.attributes.isDemo ? "sparkles" : "graduationcap.fill").foregroundStyle(.mint)
            } compactTrailing: {
                countdown(context).font(.caption2.monospacedDigit()).frame(width: 54)
            } minimal: {
                Image(systemName: "graduationcap.fill").foregroundStyle(.mint)
            }
            .keylineTint(.mint)
            .widgetURL(URL(string: "usosglass://today"))
        }
    }
    @ViewBuilder private func countdown(_ context: ActivityViewContext<ClassActivity>) -> some View {
        if context.isStale || context.state.end <= Date() {
            Image(systemName: "checkmark.circle")
        } else {
            Text(timerInterval: context.state.launched...context.state.end, countsDown: true)
        }
    }
}
