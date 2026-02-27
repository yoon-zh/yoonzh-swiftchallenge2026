// MyApp.swift
import SwiftUI

@available(iOS 26.0, *)
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            GeometryReader { reader in
                if reader.size.height > reader.size.width {
                    Text("Rotate!")
                } else {
                    FourierSketchpadView()
                }
            }
        }
    }
}
