//  MIT License
//
//  Copyright (c) 2022 AsyncSwift
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import CoreLocation.CLLocation

class RequestAuthorizationPerformer: AnyLocationPerformer {
  private let currentStatus: CLAuthorizationStatus
  private var applicationStateMonitor: ApplicationStateMonitor?
  
  init(currentStatus: CLAuthorizationStatus) {
    self.currentStatus = currentStatus
  }
  
  var typeIdentifier: ObjectIdentifier {
    return ObjectIdentifier(Self.self)
  }
  
  var uniqueIdentifier: UUID = UUID()
  
  var eventsSupport: [CoreLocationEventSupport] = [.didChangeAuthorization]
  
  private var continuation: AuthotizationContinuation?
  
  weak var cancellable: Cancellable?
  
  func linkContinuation(_ continuation: AuthotizationContinuation) {
    self.continuation = continuation
    Task { await start() }
  }
  
  func start() async {
    applicationStateMonitor = await ApplicationStateMonitor()
    await applicationStateMonitor?.startMonitoringApplicationState()
    
    Task {
      guard let monitor = applicationStateMonitor else { return }
      
      do {
        try await Task.sleep(nanoseconds: UInt64(Double(NSEC_PER_SEC) * 0.3))
        try Task.checkCancellation()
        
        if await !monitor.hasResignedActive {
          await monitor.stopMonitoringApplicationState()
          await MainActor.run {
            self.invokedMethod(event: .didChangeAuthorization(status: self.currentStatus))
          }
        }
      } catch {
        await monitor.stopMonitoringApplicationState()
      }
    }
  }
  
  func eventSupported(_ event: CoreLocationDelegateEvent) -> Bool {
    return eventsSupport.contains(event.rawEvent())
  }
  
  func invokedMethod(event: CoreLocationDelegateEvent) {
    switch event {
      case .didChangeAuthorization(let status):
        if status != .notDetermined {
          Task {
            if let monitor = applicationStateMonitor,
               await monitor.hasResignedActive {
              _ = await monitor.hasBecomeActive()
            }
            
            await MainActor.run {
              guard let continuation = self.continuation else {
                self.cancellable?.cancel(for: self)
                return
              }
              
              continuation.resume(returning: status)
              self.continuation = nil
              
              self.cancellable?.cancel(for: self)
            }
          }
        }
      default:
        break
    }
  }
  
  func cancelation() {
    Task {
      await applicationStateMonitor?.stopMonitoringApplicationState()
    }
  }
}
