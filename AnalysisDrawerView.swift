// AnalysisDrawerView.swift
struct AnalysisDrawerView: View {
    let epicycles: [Epicycle]
    @Binding var smoothness: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Analysis")
                .font(.title2.bold())
            
            if epicycles.isEmpty {
                Text("Awaiting data...")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // 1. SMOOTHNESS SLIDER
                        VStack(alignment: .leading) {
                            Text("Smoothness Filter")
                                .font(.headline)
                            Text("Keeping top \(Int(smoothness * 100))% of frequencies")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $smoothness, in: 0.01...1.0)
                                .tint(.blue)
                        }
                        
                        Divider()
                        
                        // 2. PEAK VALUES
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top 3 Peaks").font(.headline)
                            let topPeaks = Array(epicycles.prefix(3))
                            ForEach(0..<topPeaks.count, id: \.self) { i in
                                let epi = topPeaks[i]
                                HStack {
                                    Text("#\(i+1)")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                    Text("Freq: \(epi.frequency)")
                                    Spacer()
                                    Text("Amp: \(String(format: "%.1f", epi.amplitude))")
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        Divider()
                        
                        // 3. MAGNITUDE SPECTRUM
                        VStack(alignment: .leading) {
                            Text("Magnitude Spectrum").font(.headline)
                            Text("Frequency vs. Amplitude").font(.caption).foregroundColor(.secondary)
                            
                            // We only graph the top 50 so the chart remains readable
                            Chart(epicycles.prefix(50)) { epi in
                                BarMark(
                                    x: .value("Frequency", epi.frequency),
                                    y: .value("Amplitude", epi.amplitude)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                            .frame(height: 150)
                        }
                        
                        Divider()
                        
                        // 4. PHASE SPECTRUM
                        VStack(alignment: .leading) {
                            Text("Phase Spectrum").font(.headline)
                            Text("Frequency vs. Start Angle").font(.caption).foregroundColor(.secondary)
                            
                            Chart(epicycles.prefix(50)) { epi in
                                PointMark(
                                    x: .value("Frequency", epi.frequency),
                                    y: .value("Phase", epi.phase)
                                )
                                .foregroundStyle(Color.purple)
                            }
                            .frame(height: 150)
                            // Set Y-axis to radians (-pi to pi)
                            .chartYScale(domain: -Double.pi...Double.pi) 
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        // Shadow to separate the drawer from the main view
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: -5, y: 0) 
    }
}