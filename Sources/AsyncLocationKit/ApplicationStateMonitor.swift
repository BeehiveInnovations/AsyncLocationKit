//
//  ApplicationStateMonitor.swift
//  AsyncLocationKit
//
//  Created by David Whetstone on 11/28/22.
//

import Foundation

@MainActor
class ApplicationStateMonitor {
  private(set) var hasResignedActive = false
  
  private var hasResignedActiveTask: Task<Void, Never>?
  private var hasBecomeActiveTask: Task<Void, Never>?
  
  deinit {
    // Synchronous cancellation is safe
    hasResignedActiveTask?.cancel()
    hasBecomeActiveTask?.cancel()
    
    hasResignedActiveTask = nil
    hasBecomeActiveTask = nil
  }
  
  func startMonitoringApplicationState() {
    guard #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) else { return }
    startMonitoringHasResignedActive()
    startMonitoringHasBecomeActive()
  }
  
  func stopMonitoringApplicationState() {
    guard #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) else { return }
    stopMonitoringHasResignedActive()
    stopMonitoringHasBecomeActive()
  }
  
  func hasResignedActive() async -> Bool {
    guard #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *),
          let sequence = _hasResignedActiveSequence as? AsyncMapSequence<NotificationCenter.Notifications, Bool> else {
      return false
    }
    var iter = sequence.makeAsyncIterator()
    return await iter.next() != nil
  }
  
  func hasBecomeActive() async -> Bool {
    guard #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *),
          let sequence = _hasBecomeActiveSequence as? AsyncMapSequence<NotificationCenter.Notifications, Bool> else {
      return false
    }
    var iter = sequence.makeAsyncIterator()
    return await iter.next() != nil
  }
  
  @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
  private func startMonitoringHasResignedActive() {
    stopMonitoringHasResignedActive() // Cancel existing task if any
    
    hasResignedActiveTask = Task {
      guard let sequence = _hasResignedActiveSequence as? AsyncMapSequence<NotificationCenter.Notifications, Bool> else {
        return
      }
      
      for await _ in sequence {
        if Task.isCancelled { break }
        self.hasResignedActive = true
        self.stopMonitoringHasResignedActive()
      }
    }
  }
  
  @available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
  private func startMonitoringHasBecomeActive() {
    stopMonitoringHasBecomeActive() // Cancel existing task if any
    
    hasBecomeActiveTask = Task {
      guard let sequence = _hasBecomeActiveSequence as? AsyncMapSequence<NotificationCenter.Notifications, Bool> else {
        return
      }
      
      for await _ in sequence {
        if Task.isCancelled { break }
        self.stopMonitoringHasBecomeActive()
      }
    }
  }
  
  private func stopMonitoringHasResignedActive() {
    hasResignedActiveTask?.cancel()
    hasResignedActiveTask = nil
  }
  
  private func stopMonitoringHasBecomeActive() {
    hasBecomeActiveTask?.cancel()
    hasBecomeActiveTask = nil
  }
  
  // Using optional casting instead of force casting
  private var _hasResignedActiveSequence: Any? = {
    guard #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) else { return nil }
    return NotificationCenter.default.notifications(named: NotificationNamesConstants.willResignActiveName).map { _ in true }
  }()
  
  private var _hasBecomeActiveSequence: Any? = {
    guard #available(macOS 12, iOS 15, tvOS 15, watchOS 8, *) else { return nil }
    return NotificationCenter.default.notifications(named: NotificationNamesConstants.didBecomeActiveName).map { _ in true }
  }()
}
