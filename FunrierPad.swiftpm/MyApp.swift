// MyApp.swift
import SwiftUI

@available(iOS 26.0, *)
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            GeometryReader { reader in
                if reader.size.height > reader.size.width {
                    VStack(spacing: 16) {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 56, weight: .medium))
                            
                        Text("Rotate me!")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                } else {
                    FourierSketchpadView()
                }
            }
        }
    }
}