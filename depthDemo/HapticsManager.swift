//
//  HapticsManager.swift
//  depthDemo
//
//  Created by Amanda Wagner on 1/25/23.
//

import Foundation
import UIKit
import CoreHaptics


final class HapticsManager {
    static let shared = HapticsManager ()
    
    private init() {}
    public func selectionVibrate() {
        DispatchQueue.main.async {
            let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
            selectionFeedbackGenerator.prepare()
            selectionFeedbackGenerator.selectionChanged()
        }
    }
    
    public func vibrate(for type: UINotificationFeedbackGenerator.FeedbackType) {
        DispatchQueue.main.async {
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.prepare()
            notificationGenerator.notificationOccurred(type)
        }
    }
    
    public func highIntensity() {
  
    }
}

