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
        // 1. Wrap in a ScrollView so nothing is ever permanently cut off
        ScrollView(showsIndicators: false) {
            // 2. Reduce the spacing between elements for landscape
            VStack(spacing: 16) { 
                
                Image(systemName: icon)
                    // 3. Shrink the icon size slightly 
                    .font(.system(size: 64, weight: .light)) 
                    .foregroundColor(iconColor)
                    .padding(.top, 40)
                
                Text(title)
                    // 4. Use .title instead of .largeTitle
                    .font(.title) 
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    // 5. Force the text to grow vertically instead of truncating
                    .fixedSize(horizontal: false, vertical: true) 
                
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
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                } else {
                    // Invisible placeholder to keep the layout consistent
                    Color.clear
                        .frame(height: 50)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}