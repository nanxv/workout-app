//
//  CalendarEventSheet.swift
//  Silent Gym
//
//  Created by CHY5TK on 2026/01/02.
//

import SwiftUI
import SwiftData

#if os(iOS)
import EventKitUI
import UIKit

struct CalendarEventSheet: UIViewControllerRepresentable {
    let session: Session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // 延迟展示，确保视图控制器已准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            CalendarManager.shared.createEventForSession(
                session: session,
                presentingViewController: viewController
            ) { eventId in
                if let eventId = eventId {
                    // 保存 eventId 到 session
                    session.calendarEventId = eventId
                    try? self.modelContext.save()
                    print("Calendar event created: \(eventId)")
                } else {
                    print("Calendar event creation cancelled or failed")
                }
                self.dismiss()
            }
        }
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}
#endif

