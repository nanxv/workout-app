//
//  InlineEditComponents.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Based on Wireframe v1.8.3
//

import SwiftUI

/// 行内文本编辑控件
struct InlineEditText: View {
    let value: String
    let onChange: (String) -> Void
    let placeholder: String
    @State private var isEditing = false
    @State private var draftText: String = ""
    @FocusState private var isFocused: Bool
    
    init(value: String, onChange: @escaping (String) -> Void, placeholder: String = "点击输入") {
        self.value = value
        self.onChange = onChange
        self.placeholder = placeholder
    }
    
    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .focused($isFocused)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .onSubmit {
                    commit()
                }
                .onAppear {
                    draftText = value
                    isFocused = true
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        commit()
                    }
                }
        } else {
            Button(action: {
                isEditing = true
            }) {
                Text(value.isEmpty ? placeholder : value)
                    .font(.subheadline)
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func commit() {
        isEditing = false
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != value {
            onChange(trimmed)
        } else {
            draftText = value
        }
    }
}

/// 行内数字编辑控件
struct InlineEditNumber: View {
    let value: Int?
    let onChange: (Int?) -> Void
    let placeholder: String
    let min: Int?
    let max: Int?
    let step: Int
    
    @State private var isEditing = false
    @State private var draftText: String = ""
    @FocusState private var isFocused: Bool
    
    init(
        value: Int?,
        onChange: @escaping (Int?) -> Void,
        placeholder: String = "—",
        min: Int? = nil,
        max: Int? = nil,
        step: Int = 1
    ) {
        self.value = value
        self.onChange = onChange
        self.placeholder = placeholder
        self.min = min
        self.max = max
        self.step = step
    }
    
    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .focused($isFocused)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .monospacedDigit()
                .onSubmit {
                    commit()
                }
                .onAppear {
                    draftText = value?.description ?? ""
                    isFocused = true
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        commit()
                    }
                }
        } else {
            Button(action: {
                isEditing = true
            }) {
                Text(value?.description ?? placeholder)
                    .font(.subheadline)
                    .foregroundColor(value != nil ? .primary : .secondary)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func commit() {
        isEditing = false
        if draftText.isEmpty {
            onChange(nil)
        } else if let intValue = Int(draftText) {
            let clamped: Int
            if let min = min, intValue < min {
                clamped = min
            } else if let max = max, intValue > max {
                clamped = max
            } else {
                clamped = intValue
            }
            onChange(clamped)
        } else {
            draftText = value?.description ?? ""
        }
    }
}

/// 行内浮点数编辑控件（用于重量）
struct InlineEditDouble: View {
    let value: Double?
    let onChange: (Double?) -> Void
    let placeholder: String
    let min: Double?
    let max: Double?
    
    @State private var isEditing = false
    @State private var draftText: String = ""
    @FocusState private var isFocused: Bool
    
    init(
        value: Double?,
        onChange: @escaping (Double?) -> Void,
        placeholder: String = "—",
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.value = value
        self.onChange = onChange
        self.placeholder = placeholder
        self.min = min
        self.max = max
    }
    
    var body: some View {
        if isEditing {
            TextField(placeholder, text: $draftText)
                .focused($isFocused)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .monospacedDigit()
                .onSubmit {
                    commit()
                }
                .onAppear {
                    draftText = value?.description ?? ""
                    isFocused = true
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        commit()
                    }
                }
        } else {
            Button(action: {
                isEditing = true
            }) {
                Text(value != nil ? String(format: "%.1f", value!) : placeholder)
                    .font(.subheadline)
                    .foregroundColor(value != nil ? .primary : .secondary)
                    .monospacedDigit()
                    .frame(width: 60, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func commit() {
        isEditing = false
        if draftText.isEmpty {
            onChange(nil)
        } else if let doubleValue = Double(draftText) {
            let clamped: Double
            if let min = min, doubleValue < min {
                clamped = min
            } else if let max = max, doubleValue > max {
                clamped = max
            } else {
                clamped = doubleValue
            }
            onChange(clamped)
        } else {
            draftText = value?.description ?? ""
        }
    }
}

