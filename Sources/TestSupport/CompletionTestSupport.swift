import Foundation
@testable import BCLoggable

struct CameraSession {}

actor Mach5: Loggable {
   /// ` onDeployed` is NOT escaping, so this method does not return without invoking `onDeployed`.
   func deployJacks(onDeployed: @Sendable () -> Void) async throws {
      try await Task.sleep(for: .seconds(2)) // time to deploy jacks
      onDeployed()
   }

   /// ` onDeployed` is escaping, so this method returns without invoking `onDeployed`.
   func deployDrone(onDeployed: @escaping @Sendable (CameraSession) -> Void) {
      Task {
         do {
            try await Task.sleep(for: .seconds(3)) // time to deploy gizmo and start feed
            onDeployed(CameraSession())
         } catch {
            log("sleep should not have failed")
         }
      }
   }
}
