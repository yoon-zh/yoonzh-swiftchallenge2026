// WalkthroughView.swift
import SwiftUI

@available(iOS 26.0, *)
struct WalkthroughView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        TabView {
            // Page 1: The Concept
            WalkthroughPage(
                icon: "waveform.path.ecg",
                iconColor: .purple,
                title: "Welcome to Fourier Sketchpad",
                description: "Everything is a wave! This app breaks your drawings down into a chain of simple, spinning circles (sines and cosines) and uses them to rebuild your shape right before your eyes."
            )
            
            // Page 2: Inputs
            WalkthroughPage(
                icon: "hand.draw.fill",
                iconColor: .green,
                title: "Draw Your Way",
                description: "Draw directly on the left canvas, take a photo, pick an image from your album, or tap the Magic Wand to type out what you want to see (like 'star' or 'cat')."
            )
            
            // Page 3: Analysis
            WalkthroughPage(
                icon: "chart.bar.xaxis",
                iconColor: .blue,
                title: "Analyze & Filter",
                description: "Tap the chart icon to open the Analysis Drawer. View the frequencies making up your drawing, and use the sliders to filter out jitters or block out the main shape!",
                showDismiss: true,
                action: {
                    isPresented = false
                }
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(UIColor.systemBackground))
    }
}

@available(iOS 26.0, *)
struct WalkthroughPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var showDismiss: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 100, weight: .light))
                .foregroundColor(iconColor)
                .padding(.bottom, 16)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            if showDismiss {
                Button(action: { action?() }) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: 220)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 60)
            } else {
                // Invisible placeholder to keep the layout centered identical to the last page
                Color.clear
                    .frame(height: 50)
                    .padding(.bottom, 60)
            }
        }
    }
}