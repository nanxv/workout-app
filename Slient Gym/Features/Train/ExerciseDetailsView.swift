//
//  ExerciseDetailsView.swift
//  Silent Gym
//
//  v2 — Zero-friction redesign
//  • Smart auto-fill from previous session (highest priority)
//  • Large stepper controls for weight & reps
//  • Giant "完成第N组" button (full-width)
//  • Inline rest countdown — no overlays, no sheets
//  • Haptic feedback on set completion
//

import SwiftUI
import SwiftData

// MARK: - ExerciseDetailsView

struct ExerciseDetailsView: View {
    let sessionExercise: SessionExercise
    let routineExercise: RoutineExercise?

    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded: Bool
    @State private var setLogs: [SetLogEntry] = []

    // Smart auto-fill: data from the most recent previous session for this exercise
    @State private var previousSetData: [SetLogEntry] = []
    @State private var usingPreviousData = false

    // Inline rest countdown (self-contained, no dependency on parent RestTimerManager)
    @State private var restingAfterSetIndex: Int? = nil
    @State private var localRestRemaining: Int = 0
    @State private var localRestTotal: Int = 1
    @State private var localTimer: Timer?

    init(sessionExercise: SessionExercise,
         routineExercise: RoutineExercise?,
         defaultExpanded: Bool = false) {
        self.sessionExercise = sessionExercise
        self.routineExercise = routineExercise
        _isExpanded = State(initialValue: defaultExpanded)
    }

    // MARK: Derived

    private var targetSets: Int   { routineExercise?.targetSets ?? 3 }
    private var isHoldType: Bool  { routineExercise?.isHoldType ?? false }
    private var hasWeight: Bool   { routineExercise?.weightKgDefault != nil }
    private var restSec: Int      { routineExercise?.restSecondsDefault ?? 90 }

    /// Index of the first set not yet completed — the one shown with full controls
    private var nextPendingIndex: Int? {
        setLogs.indices.first { !setLogs[$0].isCompleted }
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            if isExpanded {
                VStack(spacing: 10) {
                    if usingPreviousData {
                        Label("已预填充上次数据", systemImage: "arrow.counterclockwise.circle")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                    ForEach(0..<targetSets, id: \.self) { index in
                        setRow(at: index)
                        // Inline rest countdown appears directly below the just-completed set
                        if restingAfterSetIndex == index {
                            restCountdownBar
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    statsFooter
                }
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.22), value: restingAfterSetIndex)
            }
        }
        .onAppear { loadSetLogs() }
        .onDisappear { stopLocalTimer() }
        .animation(.easeInOut(duration: 0.20), value: isExpanded)
    }

    // MARK: Header

    private var headerButton: some View {
        Button { withAnimation { isExpanded.toggle() } } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sessionExercise.exercise?.name ?? "未知动作")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    if let re = routineExercise {
                        Text(planDescription(for: re))
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
                Spacer()
                progressDots
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<targetSets, id: \.self) { i in
                let done = setLogs[safe: i]?.isCompleted == true
                Circle()
                    .fill(done ? AppTheme.accent : AppTheme.border)
                    .frame(width: 7, height: 7)
            }
        }
    }

    // MARK: Set Rows

    @ViewBuilder
    private func setRow(at index: Int) -> some View {
        let log = setLogs[safe: index] ?? defaultSetLog(at: index)
        if log.isCompleted {
            completedSetRow(index: index, log: log)
        } else if nextPendingIndex == index {
            activeSetCard(index: index, log: log)
        } else {
            pendingSetRow(index: index, log: log)
        }
    }

    // Compact green row for completed sets
    private func completedSetRow(index: Int, log: SetLogEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accent)
            Text("第 \(index + 1) 组")
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if isHoldType {
                Text("\(log.holdSec ?? 0) 秒")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            } else {
                Group {
                    if let kg = log.weightKg, kg > 0 {
                        Text(String(format: "%.1f kg", kg))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Text("× \(log.reps ?? 0)")
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .sgCard()
    }

    // Dimmed row for future sets not yet reached
    private func pendingSetRow(index: Int, log: SetLogEntry) -> some View {
        HStack(spacing: 10) {
            Circle()
                .stroke(AppTheme.border, lineWidth: 1.5)
                .frame(width: 20, height: 20)
            Text("第 \(index + 1) 组")
                .font(.subheadline)
                .foregroundColor(AppTheme.textTertiary)
            Spacer()
            if isHoldType {
                Text("\(log.holdSec ?? routineExercise?.holdSecDefault ?? 0) 秒")
                    .font(.caption)
                    .foregroundColor(AppTheme.textTertiary)
            } else {
                if let kg = log.weightKg, kg > 0 {
                    Text(String(format: "%.1f kg", kg))
                        .font(.caption)
                        .foregroundColor(AppTheme.textTertiary)
                }
                if let reps = log.reps {
                    Text("× \(reps)")
                        .font(.caption)
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.border.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // Active set: large steppers + giant complete button
    private func activeSetCard(index: Int, log: SetLogEntry) -> some View {
        VStack(spacing: 20) {
            // Set label
            HStack {
                Text("第 \(index + 1) 组")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accent)
                Spacer()
                Text("完成后自动计时")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textTertiary)
            }

            // Controls
            if isHoldType {
                stepperRow(
                    label: "秒",
                    displayValue: "\(setLogs[safe: index]?.holdSec ?? routineExercise?.holdSecDefault ?? 0)",
                    onDecrement: { adjustLog(at: index) { $0.holdSec = max(0, ($0.holdSec ?? 0) - 5) } },
                    onIncrement: { adjustLog(at: index) { $0.holdSec = ($0.holdSec ?? 0) + 5 } }
                )
            } else {
                HStack(spacing: 20) {
                    if hasWeight {
                        stepperRow(
                            label: "kg",
                            displayValue: {
                                if let kg = setLogs[safe: index]?.weightKg { return String(format: "%.1f", kg) }
                                return "—"
                            }(),
                            onDecrement: {
                                adjustLog(at: index) { log in
                                    log.weightKg = max(0, (log.weightKg ?? 0) - 2.5)
                                }
                            },
                            onIncrement: {
                                adjustLog(at: index) { log in
                                    log.weightKg = (log.weightKg ?? 0) + 2.5
                                }
                            }
                        )
                    }
                    stepperRow(
                        label: "次",
                        displayValue: "\(setLogs[safe: index]?.reps ?? 0)",
                        onDecrement: { adjustLog(at: index) { $0.reps = max(0, ($0.reps ?? 0) - 1) } },
                        onIncrement: { adjustLog(at: index) { $0.reps = ($0.reps ?? 0) + 1 } }
                    )
                }
            }

            // Giant "完成" button — full width, 56 pt height
            Button { completeActiveSet(at: index) } label: {
                Text("完成第 \(index + 1) 组")
            }
            .buttonStyle(SGPrimaryButtonStyle())
        }
        .padding(18)
        .sgActiveCard()
    }

    // Stepper control: large [−] VALUE [+]
    private func stepperRow(
        label: String,
        displayValue: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.title3.bold())
                        .frame(width: 48, height: 48)
                        .background(AppTheme.surfaceElevated)
                        .foregroundColor(AppTheme.textPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text(displayValue)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(minWidth: 76, alignment: .center)
                    .monospacedDigit()
                    .lineLimit(1)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .frame(width: 48, height: 48)
                        .background(AppTheme.surfaceElevated)
                        .foregroundColor(AppTheme.textPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Text(label)
                .font(.caption.bold())
                .foregroundColor(AppTheme.textSecondary)
        }
    }

    // MARK: Inline Rest Countdown

    private var restCountdownBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "timer")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.accent)
                Text("休息 \(localRestRemaining)s")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accent)
                    .monospacedDigit()
                Spacer()
                Button("跳过") {
                    stopLocalTimer()
                    withAnimation { restingAfterSetIndex = nil }
                }
                .font(.caption.bold())
                .foregroundColor(AppTheme.textSecondary)
                .buttonStyle(.plain)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.border).frame(height: 5)
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(
                            width: geo.size.width * CGFloat(localRestRemaining) / CGFloat(max(1, localRestTotal)),
                            height: 5
                        )
                        .animation(.linear(duration: 1), value: localRestRemaining)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.accent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Stats Footer

    private var statsFooter: some View {
        let done = setLogs.filter(\.isCompleted).count
        let totalReps = setLogs.filter { $0.isCompleted && !isHoldType }
            .reduce(0) { $0 + ($1.reps ?? 0) }
        return Text(
            isHoldType
                ? "\(done)/\(targetSets) 组完成 · 休息建议 \(restSec)s"
                : "\(done)/\(targetSets) 组完成 · 总次数 \(totalReps) · 休息 \(restSec)s"
        )
        .font(.caption)
        .foregroundColor(AppTheme.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: Actions

    private func adjustLog(at index: Int, mutation: (inout SetLogEntry) -> Void) {
        guard index < setLogs.count else { return }
        var log = setLogs[index]
        mutation(&log)
        setLogs[index] = log
    }

    private func completeActiveSet(at index: Int) {
        guard index < setLogs.count else { return }
        var log = setLogs[index]
        log.isCompleted = true
        // Ensure a sensible fallback if user never touched the stepper
        if !isHoldType && (log.reps == nil || log.reps == 0) {
            log.reps = routineExercise?.repTarget ?? 0
        }
        if isHoldType && (log.holdSec == nil || log.holdSec == 0) {
            log.holdSec = routineExercise?.holdSecDefault ?? 0
        }
        setLogs[index] = log
        persistSetLog(at: index, log: log)

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        // Start local inline rest countdown
        if restSec > 0 {
            startLocalRest(seconds: restSec, afterIndex: index)
        }

        // Tell parent (TrainViewWireframe / TrainView) to also start its global timer
        NotificationCenter.default.post(
            name: NSNotification.Name("StartRestTimer"),
            object: nil,
            userInfo: ["restSeconds": restSec]
        )
    }

    // MARK: Local Rest Timer

    private func startLocalRest(seconds: Int, afterIndex: Int) {
        stopLocalTimer()
        localRestRemaining = seconds
        localRestTotal = seconds
        withAnimation { restingAfterSetIndex = afterIndex }
        localTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.localRestRemaining > 0 {
                    self.localRestRemaining -= 1
                } else {
                    self.stopLocalTimer()
                    withAnimation { self.restingAfterSetIndex = nil }
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    #endif
                }
            }
        }
    }

    private func stopLocalTimer() {
        localTimer?.invalidate()
        localTimer = nil
    }

    // MARK: Persistence

    private func persistSetLog(at index: Int, log: SetLogEntry) {
        if let existing = sessionExercise.sets?.first(where: { $0.setIndex == index }) {
            existing.isCompleted = true
            existing.reps       = log.reps ?? 0
            existing.holdSec    = log.holdSec
            existing.weightKg   = log.weightKg
            existing.rir        = 1
        } else {
            let entry = SetEntry(
                sessionExercise: sessionExercise,
                setIndex:        index,
                reps:            log.reps ?? 0,
                rir:             1,
                restSecondsUsed: 0,
                holdSec:         log.holdSec,
                weightKg:        log.weightKg,
                isCompleted:     true
            )
            modelContext.insert(entry)
        }
        try? modelContext.save()
    }

    // MARK: Load + Auto-fill

    private func loadSetLogs() {
        loadPreviousSessionData()
        let existingSets = sessionExercise.sets?.sorted { $0.setIndex < $1.setIndex } ?? []
        var logs: [SetLogEntry] = []
        for i in 0..<targetSets {
            if let set = existingSets.first(where: { $0.setIndex == i }) {
                logs.append(SetLogEntry(
                    setIndex:    i,
                    isCompleted: set.isCompleted,
                    reps:        set.reps > 0 ? set.reps : nil,
                    holdSec:     set.holdSec,
                    weightKg:    set.weightKg
                ))
            } else {
                // Cascade: previous-session actual → plan default
                let prev = previousSetData[safe: i]
                logs.append(SetLogEntry(
                    setIndex:    i,
                    isCompleted: false,
                    reps:        prev?.reps     ?? routineExercise?.repTarget,
                    holdSec:     prev?.holdSec  ?? routineExercise?.holdSecDefault,
                    weightKg:    prev?.weightKg ?? routineExercise?.weightKgDefault
                ))
            }
        }
        setLogs = logs
    }

    /// Fetch the most recent completed session's data for this exercise.
    private func loadPreviousSessionData() {
        guard let exerciseId       = sessionExercise.exercise?.id,
              let currentSessionId = sessionExercise.session?.id else { return }

        let allSE = (try? modelContext.fetch(FetchDescriptor<SessionExercise>())) ?? []
        let previousSEs = allSE
            .filter { $0.exercise?.id == exerciseId && $0.session?.id != currentSessionId }
            .sorted { ($0.session?.startAt ?? .distantPast) > ($1.session?.startAt ?? .distantPast) }

        guard let lastSE   = previousSEs.first,
              let lastSets = lastSE.sets?.sorted(by: { $0.setIndex < $1.setIndex }),
              !lastSets.isEmpty else { return }

        previousSetData = lastSets.map { set in
            SetLogEntry(
                setIndex:    set.setIndex,
                isCompleted: false,
                reps:        set.reps > 0 ? set.reps : nil,
                holdSec:     set.holdSec,
                weightKg:    set.weightKg
            )
        }
        usingPreviousData = true
    }

    private func defaultSetLog(at index: Int) -> SetLogEntry {
        SetLogEntry(
            setIndex:    index,
            isCompleted: false,
            reps:        routineExercise?.repTarget,
            holdSec:     routineExercise?.holdSecDefault,
            weightKg:    routineExercise?.weightKgDefault
        )
    }

    private func planDescription(for re: RoutineExercise) -> String {
        let detail: String
        if re.isHoldType, let s = re.holdSecDefault { detail = "×\(s)s" }
        else if let r = re.repTarget               { detail = "×\(r)次" }
        else                                       { detail = "" }
        return "\(re.targetSets)组\(detail) · 休 \(re.restSecondsDefault)s"
    }
}

// MARK: - Set Log Entry

struct SetLogEntry {
    var setIndex: Int
    var isCompleted: Bool
    var reps: Int?
    var holdSec: Int?
    var weightKg: Double?
}

// MARK: - Inline Field Components (kept for compatibility with Routines views)

struct InlineNumberField: View {
    @Binding var value: Int?
    @State private var isEditing = false
    @State private var draftText: String = ""
    let placeholder: String

    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { commit() }
                .onAppear { draftText = value?.description ?? "" }
        } else {
            Button { isEditing = true } label: {
                Text(value?.description ?? placeholder)
                    .font(.caption)
                    .foregroundColor(value != nil ? .primary : .secondary)
                    .frame(minWidth: 40)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private func commit() {
        value = Int(draftText) ?? (draftText.isEmpty ? nil : value)
        isEditing = false
    }
}

struct InlineDoubleField: View {
    @Binding var value: Double?
    @State private var isEditing = false
    @State private var draftText: String = ""
    let placeholder: String

    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { commit() }
                .onAppear { draftText = value != nil ? String(format: "%.1f", value!) : "" }
        } else {
            Button { isEditing = true } label: {
                Text(value != nil ? String(format: "%.1f", value!) : placeholder)
                    .font(.caption)
                    .foregroundColor(value != nil ? .primary : .secondary)
                    .frame(minWidth: 40)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private func commit() {
        value = Double(draftText) ?? (draftText.isEmpty ? nil : value)
        isEditing = false
    }
}

// subscript(safe:) is defined in TrainViewWireframe.swift as a global Array extension
