import Foundation

nonisolated protocol Loggable {
   static func log(_: String, function: String)
   func log(_: String, function: String)
}

extension Loggable {
   nonisolated static func log(_ message: String = "", function: String = #function) {
#if DEBUG
      print("[\(Self.self) static \(function)] \(message)")
#endif
   }

   nonisolated func log(_ message: String = "", function: String = #function) {
#if DEBUG
      print("[\(Self.self).\(function)] \(message)")
#endif
   }
}

nonisolated func log(_ message: String = "", function: String = #function) {
#if DEBUG
   print("[\(function)] \(message)")
#endif
}
