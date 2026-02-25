// FourierCalculator.swift

import Foundation
import Accelerate
import CoreGraphics

struct Epicycle: Identifiable {
    let id = UUID()
    let frequency: Int
    let amplitude: Double
    let phase: Double
}

class FourierCalculator {
    
    // MARK: - Main Pipeline (Updated)
        
        // CHANGE: Accepts [[CGPoint]] (Array of strokes) instead of [CGPoint]
        static func computeEpicycles(from rawStrokes: [[CGPoint]], sampleCount: Int = 256) -> [Epicycle] {
            // Flatten just to check if we have data
            let flatPoints = rawStrokes.flatMap { $0 }
            guard flatPoints.count > 1 else { return [] }
            
            // 1. Resample preserving gaps
            let uniformPoints = resampleStrokes(strokes: rawStrokes, targetCount: sampleCount)
            guard uniformPoints.count == sampleCount else { return [] }
            
            // 2. Prepare for FFT
            var realParts = uniformPoints.map { Float($0.x) }
            var imagParts = uniformPoints.map { Float($0.y) }
            
            // 3. Run FFT
            let fftResult = performFFT(real: &realParts, imag: &imagParts)
            
            // 4. Convert (With Negative Frequency Fix)
            var epicycles = convertToEpicycles(real: fftResult.real, imag: fftResult.imag)
            
            // 5. Sort by Amplitude
            epicycles.sort { $0.amplitude > $1.amplitude }
            
            return epicycles
        }
    
    // MARK: - Helper: Reconstruct Path
    // We pre-calculate the "Perfect Trace" so the UI doesn't have to do it 60 times a second
    static func reconstructPath(from epicycles: [Epicycle], sampleCount: Int) -> [CGPoint] {
        var pathPoints: [CGPoint] = []
        
        // We simulate one full cycle (t = 0 to 2pi)
        for i in 0..<sampleCount {
            let t = (Double(i) / Double(sampleCount)) * 2.0 * .pi
            
            // Sum all vectors at time t
            var x: Double = 0
            var y: Double = 0
            
            for epi in epicycles {
                let angle = epi.phase + (Double(epi.frequency) * t)
                x += epi.amplitude * cos(angle)
                y += epi.amplitude * sin(angle)
            }
            pathPoints.append(CGPoint(x: x, y: y))
        }
        return pathPoints
    }

    // MARK: - Resampling (Gap-Skipping Version)
    private static func resampleStrokes(strokes: [[CGPoint]], targetCount: Int) -> [CGPoint] {
        // 1. Calculate total length of ACTUAL INK (ignoring gaps)
        var totalInkLength: CGFloat = 0
        var strokeLengths: [CGFloat] = []
        
        for stroke in strokes {
            var len: CGFloat = 0
            if stroke.count > 1 {
                for i in 0..<stroke.count - 1 {
                    len += distance(stroke[i], stroke[i+1])
                }
            }
            strokeLengths.append(len)
            totalInkLength += len
        }
        
        if totalInkLength == 0 { return [] }
        
        // 2. Distribute samples based on stroke length contribution
        var finalPoints: [CGPoint] = []
        
        for (index, stroke) in strokes.enumerated() {
            guard stroke.count > 1 else { continue }
            
            // How many points does this stroke deserve?
            // We use standard rounding, but ensure at least 1 point if meaningful
            let strokeShare = strokeLengths[index] / totalInkLength
            let strokeSampleCount = Int(Double(targetCount) * strokeShare)
            
            if strokeSampleCount > 1 {
                let resampledStroke = resampleSingleStroke(points: stroke, targetCount: strokeSampleCount)
                finalPoints.append(contentsOf: resampledStroke)
            }
        }
        
        // 3. Pad or Trim to match exact targetCount (FFT strict requirement)
        // Because of rounding, we might be off by a few points.
        if finalPoints.isEmpty { return [] }
        
        // Loop wrapping logic to fill gaps if under-sampled
        while finalPoints.count < targetCount {
            finalPoints.append(finalPoints.last!)
        }
        // Trim if over-sampled
        if finalPoints.count > targetCount {
            finalPoints = Array(finalPoints.prefix(targetCount))
        }
        
        return finalPoints
    }
    
    // Helper for a single stroke (Same logic as before, just scoped)
    private static func resampleSingleStroke(points: [CGPoint], targetCount: Int) -> [CGPoint] {
        var totalLength: CGFloat = 0
        for i in 0..<points.count - 1 {
            totalLength += distance(points[i], points[i+1])
        }
        
        let interval = totalLength / CGFloat(targetCount - 1)
        var newPoints: [CGPoint] = [points.first!]
        var currentPathDist: CGFloat = 0
        var nextSampleDist: CGFloat = interval
        
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i+1]
            let segmentLength = distance(p1, p2)
            
            while currentPathDist + segmentLength >= nextSampleDist {
                let distInto = nextSampleDist - currentPathDist
                let t = distInto / segmentLength
                let newX = p1.x + (p2.x - p1.x) * t
                let newY = p1.y + (p2.y - p1.y) * t
                newPoints.append(CGPoint(x: newX, y: newY))
                nextSampleDist += interval
                if newPoints.count >= targetCount { break }
            }
            currentPathDist += segmentLength
            if newPoints.count >= targetCount { break }
        }
        
        // Local cleanup
        while newPoints.count < targetCount { newPoints.append(points.last!) }
        return newPoints
    }
    
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
    // MARK: - FFT Implementation
    private static func performFFT(real: inout [Float], imag: inout [Float]) -> (real: [Float], imag: [Float]) {
        let n = real.count
        
        // FIX: Prevent crash on empty arrays or single points
        guard n > 1 else { return (real, imag) }
        
        let log2n = vDSP_Length(log2(Float(n)))
        
        // Optional safety: ensure n is actually a power of 2 to match the log2 calculation
        // (Though your resampling logic usually forces 256, this handles edge cases)
        let powerOfTwo = Int(pow(2.0, Double(log2n)))
        guard n == powerOfTwo else {
            print("FFT Error: Sample count \(n) is not a power of 2")
            return (real, imag)
        }
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return (real, imag) }
        
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexBuffer = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }
        vDSP_destroy_fftsetup(fftSetup)
        return (real, imag)
    }
    
    // MARK: - Convert & Frequency Fix
    private static func convertToEpicycles(real: [Float], imag: [Float]) -> [Epicycle] {
        let n = Float(real.count)
        var epicycles: [Epicycle] = []
        
        for k in 0..<real.count {
            let re = real[k]
            let im = imag[k]
            
            // CRITICAL FIX: Handle Negative Frequencies
            // Indices 0...N/2 are positive. Indices N/2+1...N-1 are negative.
            var freq = k
            if k > Int(n) / 2 {
                freq = k - Int(n)
            }
            
            let amp = sqrt(re * re + im * im) / n
            let phase = atan2(im, re)
            
            epicycles.append(Epicycle(frequency: freq, amplitude: Double(amp), phase: Double(phase)))
        }
        return epicycles
    }
}
