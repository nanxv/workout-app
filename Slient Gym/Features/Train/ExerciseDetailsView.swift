//
//  ExerciseDetailsView.swift
//  Silent Gym
//
//  v3 — Single-source-of-truth architecture
//  • RestTimerManager injected from parent (no local Timer — eliminates state split)
//  • onSetCompleted callback replaces NotificationCenter hack
//  • isRestingForThisExercise flag: this view knows only IF it triggered the rest
//  • RIR quick picker: 3 color blocks (力竭 / 余1-2 / 轻松)
//  • Smart auto-fill from previous session still intact
//

import SwiftUI
import SwiftData

// MARK: - RIR Option

private struct RIROption: Identifiable {
    let id: Int  // == rir value stored
    let label: String
    let color: Color
}

private let rirOptions: [RIROption] = [
    RIROption(id: 0, label: "力竭",  color: AppTheme.destructive),
    RIROption(id: 1, label: "余1-2", color: AppTheme.warning),
    RIROption(id: 3, label: "轻松",  color: AppTheme.success),
]

// MARK: - ExerciseDetailsView

struct ExerciseDetailsView: View {
    let sessionExercise: SessionExercise
    let routineExercise: RoutineExercise?
    /// Global rest timer — SINGLE source of truth for countdown display
    @ObservedObject var restTimer: RestTimerManager
    /// Called when user completes a set; parent starts rest + updates session state
    let onSetCompleted: (Int) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded: Bool
    @State private var setLogs: [SetLogEntry] = []
    @State private var previousSetData: [SetLogEntry] = []
    @State private var usingPreviousData = false

    // This flag tracks only whether THIS exercise triggered the currently-running rest.
    // Reset when restTimer stops — no local Timer needed.
    @State private var isRestingForThisExercise = false
    @State private var lastRestTotal: Int = 90   // UI hint for progress-bar width

    init(sessionExercise: SessionExercise,
         routineExercise: RoutineExercise?,
         defaultExpanded: Bool = false,
         restTimer: RestTimerManager,
         onSetCompleted: @escaping (Int) -> Void) {
        self.sessionExercise = sessionExercise
        self.routineExercise = routineExercise
        self.restTimer = restTimer
        self.onSetCompleted = onSetCompleted
        _isExpanded = State(initialValue: defaultExpanded)
    }

    // MARK: Derived

    private var targetSets: Int  { routineExercise?.targetSets ?? 3 }
    private var isHoldType: Bool { routineExercise?.isHoldType ?? false }
    private var hasWeight: Bool  { routineExercise?.weightKgDefault != nil }
    private var restSec: Int     { routineExercise?.restSecondsDefault ?? 90 }

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
                        if isRestingForThisExercise && nextPendingIndex == index + 1 {
                            restCountdownBar
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    statsFooter
                }
                .padding(.bottom, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear { loadSetLogs() }
        // When global restTimer stops, clear this exercise's resting flag
        .onChange(of: restTimer.state) { _, newState in
            if case .off = newState {
                withAnimation { isRestingForThisExercise = false }
            }
        }
        .animation(.easeInOut(duration: 0.20), value: isExpanded)
        .animation(.easeInOut(duration: 0.25), value: isRestingForThisExercise)
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
                Circle()
                    .fill(setLogs[safe: i]?.isCompleted == true ? AppTheme.accent : AppTheme.border)
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

    private func completedSetRow(index: Int, log: SetLogEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accent)
            Text("第 \(index + 1) 组")
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
            if isHoldType {
                Text("\(log.holdSec ?? 0)s")
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
                // RIR badge
                if let rirOpt = rirOptions.first(where: { $0.id == (log.rir == 0 ? 0 : log.rir >= 3 ? 3 : 1) }) {
                    Text(rirOpt.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(rirOpt.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(Capsule().stroke(rirOpt.color.opacity(0.5), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .sgCard()
    }

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
                Text("\(log.holdSec ?? routineExercise?.holdSecDefault ?? 0)s")
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
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    // Active set: large steppers + RIR picker + giant button
    private func activeSetCard(index: Int, log: SetLogEntry) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("第 \(index + 1) 组")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accent)
                Spacer()
                Text("完成后自动计时")
                    .font(.caption2)
                    .foregroundColor(AppTheme.textTertiary)
            }

            // Weight / reps / hold steppers
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
                            onDecrement: { adjustLog(at: index) { $0.weightKg = max(0, ($0.weightKg ?? 0) - 2.5) } },
                            onIncrement: { adjustLog(at: index) { $0.weightKg = ($0.weightKg ?? 0) + 2.5 } }
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

            // RIR quick picker — 3 colored blocks, no Picker system control
            rirPicker(at: index)

            // Giant "完成" button — full width
            Button { completeActiveSet(at: index) } label: {
                Text("完成第 \(index + 1) 组")
            }
            .buttonStyle(SGPrimaryButtonStyle())
        }
        .padding(18)
        .sgActiveCard()
    }

    // Stepper: [−]  VALUE  [+]
    private func stepperRow(label: String, displayValue: String,
                             onDecrement: @escaping () -> Void,
                             onIncrement: @escaping () -> Void) -> some View {
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

    // RIR: 3 color-coded blocks instead of system Picker
    private func rirPicker(at index: Int) -> some View {
        let currentRIR = setLogs[safe: index]?.rir ?? 1
        return HStack(spacing: 6) {
            ForEach(rirOptions) { opt in
                let isSelected = (opt.id == 0 && currentRIR == 0) ||
                                 (opt.id == 1 && currentRIR > 0 && currentRIR < 3) ||
                                 (opt.id == 3 && currentRIR >= 3)
                Button {
                    adjustLog(at: index) { $0.rir = opt.id }
                } label: {
                    Text(opt.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? AppTheme.accentForeground : opt.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? opt.color : opt.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Inline Rest Countdown (driven by global restTimer)

    private var restCountdownBar: some View {
        let remaining = restTimer.remainingSeconds
        let total = max(1, lastRestTotal)
        return VStack(spacing: 8) {
            HStack {
                Image(systemName: "timer")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.accent)
                Text(restTimerLabel)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.accent)
                    .monospacedDigit()
                Spacer()
                Button("跳过") {
                    // Caller (TrainViewWireframe) handles skip via onSkip pattern;
                    // here we just clear the local flag visually
                    withAnimation { isRestingForThisExercise = false }
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
                        .frame(width: geo.size.width * CGFloat(remaining) / CGFloat(total), height: 5)
                        .animation(.linear(duration: 0.2), value: remaining)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.accent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var restTimerLabel: String {
        switch restTimer.state {
        case .running(let r): return "休息 \(r)s"
        case .paused(let r):  return "已暂停 \(r)s"
        case .off:            return "休息完毕"
        }
    }

    // MARK: Stats Footer

    private var statsFooter: some View {
        let done = setLogs.filter(\.isCompleted).count
        let totalReps = setLogs.filter { $0.isCompleted && !isHoldType }.reduce(0) { $0 + ($1.reps ?? 0) }
        return Text(
            isHoldType
                ? "\(done)/\(targetSets) 组完成 · 休息 \(restSec)s"
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
        if !isHoldType && (log.reps == nil || log.reps == 0) { log.reps = routineExercise?.repTarget ?? 0 }
        if isHoldType  && (log.holdSec == nil || log.holdSec == 0) { log.holdSec = routineExercise?.holdSecDefault ?? 0 }
        setLogs[index] = log
        persistSetLog(at: index, log: log)

        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        if restSec > 0 {
            lastRestTotal = restSec
            // Mark THIS exercise as the one that triggered rest, before calling parent
            withAnimation { isRestingForThisExercise = true }
            // Delegate rest start to parent — single source of truth
            onSetCompleted(restSec)
        }
    }

    // MARK: Persistence

    private func persistSetLog(at index: Int, log: SetLogEntry) {
        if let existing = sessionExercise.sets?.first(where: { $0.setIndex == index }) {
            existing.isCompleted = true
            existing.reps        = log.reps ?? 0
            existing.holdSec     = log.holdSec
            existing.weightKg    = log.weightKg
            existing.rir         = log.rir
        } else {
            let entry = SetEntry(
                sessionExercise: sessionExercise,
                setIndex:        index,
                reps:            log.reps ?? 0,
                rir:             log.rir,
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
                    setIndex: i, isCompleted: set.isCompleted,
                    reps: set.reps > 0 ? set.reps : nil,
                    holdSec: set.holdSec, weightKg: set.weightKg, rir: set.rir
                ))
            } else {
                let prev = previousSetData[safe: i]
                logs.append(SetLogEntry(
                    setIndex: i, isCompleted: false,
                    reps:     prev?.reps     ?? routineExercise?.repTarget,
                    holdSec:  prev?.holdSec  ?? routineExercise?.holdSecDefault,
                    weightKg: prev?.weightKg ?? routineExercise?.weightKgDefault,
                    rir:      prev?.rir      ?? 1
                ))
            }
        }
        setLogs = logs
    }

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
            SetLogEntry(setIndex: set.setIndex, isCompleted: false,
                        reps: set.reps > 0 ? set.reps : nil,
                        holdSec: set.holdSec, weightKg: set.weightKg, rir: set.rir)
        }
        usingPreviousData = true
    }

    private func defaultSetLog(at index: Int) -> SetLogEntry {
        SetLogEntry(setIndex: index, isCompleted: false,
                    reps: routineExercise?.repTarget,
                    holdSec: routineExercise?.holdSecDefault,
                    weightKg: routineExercise?.weightKgDefault,
                    rir: 1)
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
    var rir: Int = 1
}

// MARK: - Inline field components (kept for Routines views compatibility)

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

// subscript(safe:) is defined in TrainViewWireframe.swift
