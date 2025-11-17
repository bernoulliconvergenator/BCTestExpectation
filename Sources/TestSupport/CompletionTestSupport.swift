import Foundation

struct CameraSession {}

actor Mach5 {
   /// ` onDeployed` is NOT escaping, so this method does not return without invoking `onDeployed`.
   func deployJacks(onDeployed: @Sendable () -> Void) async {
      try? await Task.sleep(for: .seconds(2)) // time to deploy jacks
      onDeployed()
   }

   /// ` onDeployed` IS escaping, so this method may return without invoking `onDeployed`.
   func deployDrone(onDeployed: @escaping @Sendable (CameraSession) -> Void) {
      Task {
         try await Task.sleep(for: .seconds(3)) // time to deploy gizmo and start feed
         onDeployed(CameraSession())
      }
   }
}
