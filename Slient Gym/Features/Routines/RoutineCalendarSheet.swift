//
//  RoutineCalendarSheet.swift
//  Slient Gym
//
//  Created by CHY5TK on 2026/01/02.
//  Allow users to schedule training routines to calendar in advance
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit

struct RoutineCalendarSheet: View {
    let routine: Routine
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var showDatePicker = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section("选择日期") {
                    DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                Section("选择时间") {
                    DatePicker("时间", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                
                Section {
                    let combinedDate = combineDateAndTime(date: selectedDate, time: selectedTime)
                    Button(action: {
                        addToCalendar(startDate: combinedDate)
                    }) {
                        HStack {
                            Spacer()
                            Text("添加到日历")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("安排训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        return calendar.date(from: components) ?? date
    }
    
    private func addToCalendar(startDate: Date) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // Find the topmost view controller
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        CalendarManager.shared.createEventForRoutine(
            routine: routine,
            startDate: startDate,
            presentingViewController: topViewController
        ) { eventId in
            if eventId != nil {
                print("Routine scheduled to calendar: \(eventId ?? "unknown")")
            }
            dismiss()
        }
    }
}
#endif


