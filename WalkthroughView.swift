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
                description: "Draw directly on the left canvas, use an image (album or camera), or tap the Magic Wand to type out what you want to see (like 'star' or 'cat')."
            )
            
            // Page 3: Analysis
            WalkthroughPage(
                icon: "chart.bar.xaxis",
                iconColor: .blue,
                title: "Analyze & Filter",
                description: "Tap the chart icon and learn about real-life applications, see the frequencies making up your drawing, and change them to transform your shapes!",
                showDismiss: true,
                action: {
                    isPresented = false
                }
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                isPresented = false
            }
            .padding(.trailing, 24)
            .padding(.top, 24)
            .font(.headline)
            .foregroundColor(.secondary)
        }
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

@available(iOS 26.0, *)
struct CompressionWalkthroughView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        TabView {
            WalkthroughPage(
                icon: "photo.badge.arrow.down.fill",
                iconColor: .green,
                title: "The Magic of Compression",
                description: "Ever wonder how huge images and audio tracks fit on your phone? Formats like JPEG and MP3 use the Fourier Transform to shrink file sizes by throwing away data you won't even notice is missing."
            )
            
            WalkthroughPage(
                icon: "ear",
                iconColor: .blue,
                title: "Dropping the Quiet Parts",
                description: "Just like an MP3 deletes the 'quietest' frequencies that your ears can't hear over the loud ones, our simulator finds the smallest, least important epicycles and removes them."
            )
            
            WalkthroughPage(
                icon: "slider.horizontal.3",
                iconColor: .purple,
                title: "Try It Yourself",
                description: "Use the 'Data Limit' slider in the drawer. Watch how far you can drop the percentage before the drawing actually starts to look bad. You'll be surprised how few epicycles you actually need!",
                showDismiss: true,
                action: { isPresented = false }
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                isPresented = false
            }
            .padding(.trailing, 24)
            .padding(.top, 24)
            .font(.headline)
            .foregroundColor(.secondary)
        }
    }
}

@available(iOS 26.0, *)
struct MorphWalkthroughView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        TabView {
            WalkthroughPage(
                icon: "sparkles",
                iconColor: .purple,
                title: "Latent Space & Morphing",
                description: "If you try to morph a dog into a cat by simply sliding their lines together on a canvas, you get a tangled mess. But if you morph their frequencies, something magical happens."
            )
            
            WalkthroughPage(
                icon: "waveform",
                iconColor: .blue,
                title: "Frequency Interpolation",
                description: "This is called Cross-Synthesis or Interpolation. Instead of moving points in space, we transition the frequencies of the shapes until they match."
            )
            
            WalkthroughPage(
                icon: "square.2.layers.3d",
                iconColor: .green,
                title: "Try It Yourself",
                description: "Draw a simple shape and tap 'Save Shape A'. Clear the canvas, draw a different shape, and tap 'Save Shape B'. Then use the slider to watch the math smoothly transform one shape into the other!",
                showDismiss: true,
                action: { isPresented = false }
            )
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(UIColor.systemBackground))
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                isPresented = false
            }
            .padding(.trailing, 24)
            .padding(.top, 24)
            .font(.headline)
            .foregroundColor(.secondary)
        }
    }
}