// AnalysisDrawerView.swift
import SwiftUI
import Charts

struct AnalysisDrawerView: View {
    let epicycles: [Epicycle]
    
    // Bindings
    @Binding var showDrawer: Bool
    @Binding var minFreqRatio: Double
    @Binding var maxFreqRatio: Double
    
    // Alert States
    @State private var showFilterInfo = false
    @State private var showMagInfo = false
    @State private var showPhaseInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header with explicit Close Button
            HStack {
                Text("Analysis")
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
            .padding(.bottom, 8)
            
            if epicycles.isEmpty {
                Text("Awaiting data...")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
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
                            Text("Frequency vs. Start Angle").font(.caption).foregroundColor(.secondary)
                            
                            Chart(epicycles.prefix(50)) { epi in
                                PointMark(
                                    x: .value("Frequency", epi.frequency),
                                    y: .value("Phase", epi.phase)
                                )
                                .foregroundStyle(Color.purple)
                            }
                            .frame(height: 150)
                            .chartYScale(domain: -Double.pi...Double.pi)
                        }
                        .alert("Phase Spectrum", isPresented: $showPhaseInfo) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("This shows the starting angle of each circle. Every circle has a different starting angle to match the hand drawing.")
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