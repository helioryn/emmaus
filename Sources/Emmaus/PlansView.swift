import SwiftUI
import AppKit

struct PlansView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var user: UserStore

    @State private var plans: [ReadingPlan] = []
    @State private var selectedID = "bible-year"
    @State private var selectedDay = 1

    private var selectedPlan: ReadingPlan? { plans.first { $0.id == selectedID } }

    var body: some View {
        let t = app.theme
        VStack(spacing: 0) {
            SectionHeaderBar(title: "Reading Plans", subtitle: "A path through Scripture, with your progress kept on this Mac.", theme: t)
            HStack(spacing: 0) {
                planList
                    .frame(width: 326)
                Rectangle().fill(t.border.opacity(0.6)).frame(width: 1)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(t.bg)
        .onAppear {
            if plans.isEmpty {
                plans = PlanLibrary.definitions.map { PlanLibrary.plan(for: $0, books: app.bible.books) }
            }
            if let p = selectedPlan {
                selectedDay = nextDay(in: p)
            }
        }
    }

    private var planList: some View {
        let t = app.theme
        return ScrollView {
            VStack(spacing: 10) {
                ForEach(plans) { plan in
                    let active = plan.id == selectedID
                    let progress = progress(plan)
                    Button {
                        selectedID = plan.id
                        selectedDay = nextDay(in: plan)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plan.name)
                                        .font(Typography.reading(size: 15, serif: true, weight: .semibold))
                                        .foregroundColor(active ? t.accent : t.ink)
                                    Text(plan.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundColor(t.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                ProgressRing(progress: progress, theme: t, size: 28, lineWidth: 3)
                            }
                            HStack {
                                Text("\(plan.days.count) days")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(t.secondary)
                                Text("·")
                                    .foregroundColor(t.secondary.opacity(0.4))
                                Text("\(completedCount(plan)) complete")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(t.secondary)
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(active ? t.accent.opacity(0.09) : t.card)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(active ? t.accent.opacity(0.35) : t.border.opacity(0.6), lineWidth: 0.7))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
        }
    }

    @ViewBuilder
    private var detail: some View {
        let t = app.theme
        if let plan = selectedPlan {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.name)
                                .font(Typography.reading(size: 28, serif: true, weight: .semibold))
                                .foregroundColor(t.ink)
                            Text(plan.subtitle)
                                .font(.system(size: 11.5))
                                .foregroundColor(t.secondary)
                        }
                        Spacer()
                        ProgressRing(progress: progress(plan), theme: t, size: 54, lineWidth: 5)
                    }

                    dayCard(plan: plan)

                    SectionLabel(text: "All Days", theme: t)
                    LazyVGrid(columns: Array(repeating: GridItem(.adaptive(minimum: 38), spacing: 6), count: 1), spacing: 6) {
                        ForEach(plan.days) { day in
                            let complete = user.isPlanDayComplete(plan.id, day.day)
                            let active = selectedDay == day.day
                            Button {
                                selectedDay = day.day
                            } label: {
                                Text("\(day.day)")
                                    .font(.system(size: 10.5, weight: active ? .bold : .medium))
                                    .foregroundColor(complete ? t.card : (active ? t.accent : t.secondary))
                                    .frame(width: 34, height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(complete ? t.accent : (active ? t.accent.opacity(0.14) : t.card))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(active && !complete ? t.accent.opacity(0.5) : .clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 20)
                }
                .padding(26)
                .frame(maxWidth: 780, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        } else {
            EmptyState(icon: "calendar", title: "Choose a plan", message: "Pick a reading plan to begin.", theme: t)
        }
    }

    private func dayCard(plan: ReadingPlan) -> some View {
        let t = app.theme
        let day = plan.days.first(where: { $0.day == selectedDay })
        let complete = day.map { user.isPlanDayComplete(plan.id, $0.day) } ?? false
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(selectedDay)")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundColor(t.accent)
                    Text(day?.label ?? "No reading")
                        .font(Typography.reading(size: 19, serif: true, weight: .medium))
                        .foregroundColor(t.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let day {
                    Button(complete ? "Completed" : "Mark Complete") {
                        user.setPlanDayComplete(plan.id, day.day, complete: !complete)
                    }
                    .buttonStyle(PrimaryButtonStyle(theme: t, tint: complete ? t.secondary : t.accent))
                }
            }
            if let day, !day.readings.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(Array(day.readings.enumerated()), id: \.offset) { _, loc in
                        Button {
                            app.open(loc)
                        } label: {
                            Text(ReferenceParser.label(book: loc.book, chapter: loc.chapter))
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(t.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(t.accent.opacity(0.09)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    if let first = day.readings.first { app.open(first) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "book")
                        Text("Open this reading")
                    }
                }
                .buttonStyle(SoftButtonStyle(theme: t))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(t.card))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.border.opacity(0.7), lineWidth: 0.7))
    }

    private func completedCount(_ plan: ReadingPlan) -> Int {
        plan.days.filter { user.isPlanDayComplete(plan.id, $0.day) }.count
    }

    private func progress(_ plan: ReadingPlan) -> Double {
        guard !plan.days.isEmpty else { return 0 }
        return Double(completedCount(plan)) / Double(plan.days.count)
    }

    private func nextDay(in plan: ReadingPlan) -> Int {
        plan.days.first(where: { !user.isPlanDayComplete(plan.id, $0.day) })?.day ?? plan.days.count
    }
}

struct ProgressRing: View {
    var progress: Double
    var theme: Theme
    var size: CGFloat = 36
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().strokeBorder(theme.border.opacity(0.6), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))")
                .font(.system(size: size * 0.26, weight: .semibold))
                .foregroundColor(theme.secondary)
        }
        .frame(width: size, height: size)
    }
}
