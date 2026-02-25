// ContentView.swift
import SwiftUI
import Charts

struct FourierSketchpadView: View {
    @State private var finishedStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    // The raw math output
    @State private var computedEpicycles: [Epicycle] = []
    
    // The filtered output passed to the UI
    @State private var activeEpicycles: [Epicycle] = []
    @State private var activeTrace: [CGPoint] = []
    
    @State private var showInfo = false
    
    // Drawer State
    @State private var showDrawer = false
    
    // NEW: Replaced 'smoothness' with Min and Max bounds for Band-Pass
    @State private var minFreqRatio: Double = 0.0
    @State private var maxFreqRatio: Double = 1.0

    // Foundation models text input
    @State private var textInput: String = ""
    @State private var isGenerating: Bool = false
    @State private var showTextInput: Bool = false
    
    var body: some View {
        ZStack(alignment: .top) {
            
            HStack(spacing: 0) {
                // MAIN CANVAS AREA
                HStack(spacing: 20) {
                    // LEFT PANEL: Input
                    VStack {
                        Text("Input: Draw & Lift Finger")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(radius: 5)
                            
                            ForEach(0..<finishedStrokes.count, id: \.self) { index in
                                DrawStroke(points: finishedStrokes[index])
                                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            }
                            
                            DrawStroke(points: currentStroke)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            
                            GeometryReader { geo in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                if geo.frame(in: .local).contains(value.location) {
                                                    currentStroke.append(value.location)
                                                } else {
                                                    if !currentStroke.isEmpty {
                                                        finishedStrokes.append(currentStroke)
                                                        currentStroke = []
                                                    }
                                                }
                                            }
                                            .onEnded { _ in
                                                if !currentStroke.isEmpty {
                                                    finishedStrokes.append(currentStroke)
                                                    currentStroke = []
                                                }
                                                processSignal()
                                            }
                                    )
                            }
                            .clipped()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .aspectRatio(1.0, contentMode: .fit)
                        .padding()
                        
                        Button(action: {
                            finishedStrokes = []
                            currentStroke = []
                            computedEpicycles = []
                            activeEpicycles = []
                            activeTrace = []
                        }) {
                            Label("Clear Canvas", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    // RIGHT PANEL: Output
                    VStack {
                        Text("Output: Fourier Series")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.secondarySystemBackground))
                                .shadow(radius: 5)
                            
                            if activeEpicycles.isEmpty {
                                Text("Draw something on the left!")
                                    .foregroundColor(.gray)
                            } else {
                                EpicycleView(epicycles: activeEpicycles, tracePoints: activeTrace)
                            }
                        }
                        .aspectRatio(1.0, contentMode: .fit)
                        .padding()
                    }
                }
                .padding(.top, 40)
                .padding()

                // THE SLIDE-OUT DRAWER
                if showDrawer {
                    // NEW: Pass the new states to the drawer
                    AnalysisDrawerView(
                        epicycles: computedEpicycles,
                        showDrawer: $showDrawer,
                        minFreqRatio: $minFreqRatio,
                        maxFreqRatio: $maxFreqRatio
                    )
                    .frame(width: 350)
                    .transition(.move(edge: .trailing))
                }
                
            }
            
            // TOP BUTTONS
            HStack {
                Button(action: { showInfo = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
                Spacer()
                Button(action: {
                    withAnimation(.spring()) {
                        showDrawer.toggle()
                    }
                }) {
                    Image(systemName: showDrawer ? "chart.bar.xaxis.chevron.down" : "chart.bar.xaxis")
                        .font(.system(size: 28))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // 3. NEW: FLOATING BOTTOM-LEFT CONTROLS
            VStack {
                Spacer() // Pushes everything to the bottom
                
                HStack(alignment: .bottom, spacing: 16) {
                    // The Toggle Button
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showTextInput.toggle()
                            if !showTextInput { textInput = "" } // Clear on close
                        }
                    }) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.purple)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                    }
                    
                    // The Floating Text Input Bar
                    if showTextInput {
                        HStack {
                            TextField("Type a shape (e.g., 'heart', 'cube')", text: $textInput)
                                .textFieldStyle(.plain)
                                .padding(.vertical, 8)
                                .onSubmit {
                                    Task { await generateShapeFromText(query: textInput) }
                                }
                            
                            Button(action: {
                                Task { await generateShapeFromText(query: textInput) }
                            }) {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(textInput.isEmpty ? .gray : .purple)
                                }
                            }
                            .disabled(textInput.isEmpty || isGenerating)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .frame(width: 320)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    Spacer() // Pushes the controls to the left
                }
                .padding(24) // Outer padding from the screen edges
            }
        }
        .alert("How it Works", isPresented: $showInfo) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text("Draw any shape on the left. The app breaks your drawing down into a chain of spinning circles, which work together to perfectly redraw your shape on the right.")
        }
        // NEW: Recalculate when either slider moves
        .onChange(of: minFreqRatio) { _ in applyFilter() }
        .onChange(of: maxFreqRatio) { _ in applyFilter() }
    }
    
    func processSignal() {
        let allPoints = finishedStrokes.flatMap { $0 }
        guard allPoints.count > 1 else { return }
        
        let centerX = allPoints.map { $0.x }.reduce(0, +) / CGFloat(allPoints.count)
        let centerY = allPoints.map { $0.y }.reduce(0, +) / CGFloat(allPoints.count)
        
        let centeredStrokes = finishedStrokes.map { stroke in
            stroke.map { CGPoint(x: $0.x - centerX, y: $0.y - centerY) }
        }
        
        self.computedEpicycles = FourierCalculator.computeEpicycles(from: centeredStrokes, sampleCount: 512)
        applyFilter()
    }

    // NEW: Band-Pass Filter Logic
    func applyFilter() {
        guard !computedEpicycles.isEmpty else {
            activeEpicycles = []
            activeTrace = []
            return
        }
        
        let highestFreq = computedEpicycles.map { abs($0.frequency) }.max() ?? 1
        
        // Ensure bounds don't cross to prevent crashes
        let safeMin = min(minFreqRatio, maxFreqRatio)
        let safeMax = max(minFreqRatio, maxFreqRatio)
        
        let minCutoff = Int(Double(highestFreq) * safeMin)
        let maxCutoff = Int(Double(highestFreq) * safeMax)
        
        activeEpicycles = computedEpicycles.filter { 
            let f = abs($0.frequency)
            return f >= minCutoff && f <= maxCutoff 
        }
        
        activeTrace = FourierCalculator.reconstructPath(from: activeEpicycles, sampleCount: 512)
    }

    // MARK: - Foundation Model Integration
    func generateShapeFromText(query: String) async {
        isGenerating = true
        
        // 1. CALL YOUR FOUNDATION MODEL HERE
        // Example: let response = await myLanguageModel.generate("Extract the shape intent from: \(query)")
        let detectedIntent = query.lowercased() // Mocking the LLM intent extraction
        
        // 2. GENERATE POINTS BASED ON INTENT
        var newStroke: [CGPoint] = []
        let center = CGPoint(x: 150, y: 150) // Adjust based on your canvas
        let sampleCount = 100
        
        switch detectedIntent {
        case "heart":
            // Parametric Heart
            for i in 0..<sampleCount {
                let t = (Double(i) / Double(sampleCount)) * 2.0 * .pi
                let x = 16 * pow(sin(t), 3)
                let y = -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
                
                // Scale and translate
                newStroke.append(CGPoint(x: (x * 5) + center.x, y: (y * 5) + center.y))
            }
        case "sine":
            // Sine Wave
            for i in 0..<sampleCount {
                let t = (Double(i) / Double(sampleCount)) * 4.0 * .pi
                let x = Double(i) * 2.5
                let y = sin(t) * 50
                newStroke.append(CGPoint(x: x + 50, y: y + center.y))
            }
        // Add more shapes...
        default:
            print("Model generated unrecognized shape")
        }
        
        // 3. INJECT INTO YOUR PIPELINE
        await MainActor.run {
            if !newStroke.isEmpty {
                self.finishedStrokes = [newStroke] // Replace or append
                self.processSignal() // Triggers the FFT!
            }
            self.isGenerating = false
            self.textInput = ""
        }
    }
}

struct DrawStroke: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let firstPoint = points.first else { return path }
        
        path.move(to: firstPoint)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}