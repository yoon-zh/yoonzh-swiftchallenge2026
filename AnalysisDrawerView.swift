// AnalysisDrawerView.swift
import SwiftUI
import Charts

struct AnalysisDrawerView: View {
    let epicycles: [Epicycle]
    let activeEpicyclesCount: Int
    
    // Bindings
    @Binding var showDrawer: Bool
    @Binding var minFreqRatio: Double
    @Binding var maxFreqRatio: Double
    
    // Educational Bindings
    @Binding var activeDrawerTab: Int
    @Binding var isCompressionMode: Bool
    @Binding var compressionDataLimit: Double
    @Binding var showCompressionWalkthrough: Bool
    
    // Alert States
    @State private var showFilterInfo = false
    @State private var showMagInfo = false
    @State private var showPhaseInfo = false

    // Convolution
    @Binding var isMorphMode: Bool
    @Binding var showMorphWalkthrough: Bool
    @Binding var epicyclesA: [Epicycle]
    @Binding var epicyclesB: [Epicycle]
    @Binding var morphProgress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                Text(activeDrawerTab == 1 ? "Analysis" : "Learn")
                    .font(.title2.bold())
                Spacer()
                Button(action: {
                    withAnimation(.spring()) { showDrawer = false }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding(.bottom, 4)

            // Tab Switcher
            Picker("Mode", selection: $activeDrawerTab) {
                Text("Learn").tag(0)
                Text("Analyze").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)

            if activeDrawerTab == 1 {
                // --- ANALYZE TAB ---
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // NEW: COMPRESSION SIMULATOR UI
                        if isCompressionMode {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Compression Simulator").font(.headline)
                                    Spacer()
                                    Button("Exit") {
                                        withAnimation { isCompressionMode = false }
                                    }
                                    .font(.caption).foregroundColor(.red)
                                }
                                
                                Text("Data Limit: \(Int(compressionDataLimit * 100))%")
                                    .font(.caption2).fontWeight(.bold)
                                
                                Slider(value: $compressionDataLimit, in: 0.01...1.0)
                                    .tint(.green)
                                
                                HStack {
                                    Text("Raw Points: 512").foregroundColor(.secondary)
                                    Spacer()
                                    Text("Epicycles Needed: \(activeEpicyclesCount)").bold()
                                }
                                .font(.caption)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Divider()
                        }

                        // NEW: MORPH SIMULATOR UI
                        if isMorphMode {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Shape Morphing").font(.headline)
                                    Spacer()
                                    Button("Exit") {
                                        withAnimation { isMorphMode = false }
                                    }
                                    .font(.caption).foregroundColor(.red)
                                }
                                
                                Text("1. Draw Shape A, then tap below:")
                                    .font(.caption).foregroundColor(.secondary)
                                Button(action: { epicyclesA = epicycles }) {
                                    Text(epicyclesA.isEmpty ? "Save as Shape A" : "Shape A Saved ✓")
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(epicyclesA.isEmpty ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                
                                Text("2. Draw Shape B, then tap below:")
                                    .font(.caption).foregroundColor(.secondary)
                                Button(action: { epicyclesB = epicycles }) {
                                    Text(epicyclesB.isEmpty ? "Save as Shape B" : "Shape B Saved ✓")
                                        .frame(maxWidth: .infinity)
                                        .padding(8)
                                        .background(epicyclesB.isEmpty ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                
                                if !epicyclesA.isEmpty && !epicyclesB.isEmpty {
                                    Text("Morph Progress: \(Int(morphProgress * 100))%")
                                        .font(.caption2).fontWeight(.bold)
                                        .padding(.top, 8)
                                    
                                    Slider(value: $morphProgress, in: 0.0...1.0)
                                        .tint(.purple)
                                }
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Divider()
                        }
                        
                        // 1. FREQUENCY FILTER (Band-Pass)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Frequency Filter").font(.headline)
                                Button(action: { showFilterInfo = true }) {
                                    Image(systemName: "questionmark.circle").foregroundColor(.blue)
                                }
                            }
                            Text("Remove specific speeds from the drawing.")
                                .font(.caption).foregroundColor(.secondary)
                            
                            VStack(alignment: .leading) {
                                Text("Lower Bound (High-Pass)").font(.caption2)
                                Slider(value: $minFreqRatio, in: 0.0...1.0).tint(.orange)
                                
                                Text("Upper Bound (Low-Pass)").font(.caption2)
                                Slider(value: $maxFreqRatio, in: 0.0...1.0).tint(.blue)
                            }
                        }
                        .alert("Frequency Filter", isPresented: $showFilterInfo) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("This controls which spinning circles make it into the final drawing. Keeping low frequencies gives you the general, smooth shape. Keeping high frequencies gives you the sharp corners and tiny jitters.")
                        }
                        
                        Divider()
                        
                        // 2. MAGNITUDE SPECTRUM (with conditional coloring)
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Magnitude Spectrum").font(.headline)
                                Button(action: { showMagInfo = true }) {
                                    Image(systemName: "questionmark.circle").foregroundColor(.blue)
                                }
                            }
                            Text("Frequency vs. Amplitude").font(.caption).foregroundColor(.secondary)
                            
                            let displayEpis = epicycles.prefix(50)
                            let highestFreq = epicycles.map { abs($0.frequency) }.max() ?? 1
                            
                            let safeMin = min(minFreqRatio, maxFreqRatio)
                            let safeMax = max(minFreqRatio, maxFreqRatio)
                            // Calculate cutoffs once outside the loop
                            let minCutoff = Int(Double(highestFreq) * safeMin)
                            let maxCutoff = Int(Double(highestFreq) * safeMax)
                            let maxAmp = displayEpis.map { $0.amplitude }.max() ?? 1.0
                            
                            Chart(displayEpis) { epi in
                                // NEW: Determine if this specific frequency passes the filter
                                let absFreq = abs(epi.frequency)
                                let isPassing = absFreq >= minCutoff && absFreq <= maxCutoff
                                
                                // THE FILTER GRAPH (H[k]) - Changed to subtle gray
                                RectangleMark(
                                    xStart: .value("Min Cutoff", minCutoff),
                                    xEnd: .value("Max Cutoff", maxCutoff),
                                    yStart: .value("Floor", 0),
                                    yEnd: .value("Ceiling", maxAmp)
                                )
                                .foregroundStyle(Color.gray.opacity(0.1)) // <--- CHANGED
                                
                                // THE DATA (X[k]) - Conditional coloring
                                BarMark(
                                    x: .value("Frequency", epi.frequency),
                                    y: .value("Amplitude", epi.amplitude)
                                )
                                // NEW: If passing, blue. If filtered out, dim gray.
                                .foregroundStyle(isPassing ? Color.blue.gradient : Color.gray.opacity(0.3).gradient)
                            }
                            .frame(height: 150)
                        }
                        .alert("Magnitude Spectrum", isPresented: $showMagInfo) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("This shows the size of each spinning circle. Taller bars mean larger circles. The bright blue bars are the ones currently passing through your filter and creating the drawing.")
                        }
                        
                        Divider()
                        
                        // 3. PHASE SPECTRUM
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Phase Spectrum").font(.headline)
                                Button(action: { showPhaseInfo = true }) {
                                    Image(systemName: "questionmark.circle").foregroundColor(.blue)
                                }
                            }
                            Text("Frequency vs. Start Angle (Degrees)").font(.caption).foregroundColor(.secondary)
                            
                            Chart(epicycles.prefix(50)) { epi in
                                PointMark(
                                    x: .value("Frequency", epi.frequency),
                                    y: .value("Phase", epi.phase * 180.0 / .pi) // Convert Rads to Degs
                                )
                                .foregroundStyle(Color.purple)
                            }
                            .frame(height: 150)
                            .chartYScale(domain: -180...180) // Set bounds to standard degrees
                            .chartYAxis {
                                AxisMarks(values: [-180, -90, 0, 90, 180]) { value in
                                    AxisGridLine()
                                    AxisValueLabel("\(value.as(Int.self) ?? 0)°")
                                }
                            }
                        }
                        .alert("Phase Spectrum", isPresented: $showPhaseInfo) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("This shows the starting angle of each circle. Every circle has a different starting angle to match the hand drawing.")
                        }
                    }
                }
            } else {
                // --- LEARN TAB ---
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Educational Modules")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            withAnimation {
                                isCompressionMode = true
                                showCompressionWalkthrough = true
                                activeDrawerTab = 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                VStack(alignment: .leading) {
                                    Text("How Compression Works").font(.subheadline).bold().foregroundColor(.primary)
                                    Text("Understand JPEG & MP3 data reduction").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: {
                            withAnimation {
                                isMorphMode = true
                                showMorphWalkthrough = true
                                activeDrawerTab = 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.2.layers.3d")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading) {
                                    Text("Shape Morphing").font(.subheadline).bold().foregroundColor(.primary)
                                    Text("Frequency-space interpolation").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: -5, y: 0)
    }
}