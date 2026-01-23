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
    
    // MARK: - Main Pipeline
    static func computeEpicycles(from rawPoints: [CGPoint], sampleCount: Int = 256) -> [Epicycle] {
        guard rawPoints.count > 1 else { return [] }
        
        // 1. Resample
        let uniformPoints = resample(points: rawPoints, targetCount: sampleCount)
        
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

    // MARK: - Resampling (Your FIXED version)
    private static func resample(points: [CGPoint], targetCount: Int) -> [CGPoint] {
        guard points.count > 1 else { return points }
        
        var totalLength: CGFloat = 0
        for i in 0..<points.count - 1 {
            totalLength += distance(points[i], points[i+1])
        }
        
        if totalLength == 0 { return Array(points.prefix(targetCount)) }
        
        let interval = totalLength / CGFloat(targetCount - 1)
        var newPoints: [CGPoint] = [points.first!]
        var currentPathDist: CGFloat = 0
        var nextSampleDist: CGFloat = interval
        
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i+1]
            let segmentLength = distance(p1, p2)
            
            while currentPathDist + segmentLength >= nextSampleDist {
                let distanceIntoSegment = nextSampleDist - currentPathDist
                let t = distanceIntoSegment / segmentLength
                let newX = p1.x + (p2.x - p1.x) * t
                let newY = p1.y + (p2.y - p1.y) * t
                newPoints.append(CGPoint(x: newX, y: newY))
                nextSampleDist += interval
                if newPoints.count >= targetCount { break }
            }
            currentPathDist += segmentLength
            if newPoints.count >= targetCount { break }
        }
        
        while newPoints.count < targetCount { newPoints.append(points.last!) }
        if newPoints.count > targetCount { newPoints = Array(newPoints.prefix(targetCount)) }
        
        return newPoints
    }
    
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }
    
    // MARK: - FFT Implementation
    private static func performFFT(real: inout [Float], imag: inout [Float]) -> (real: [Float], imag: [Float]) {
        let n = real.count
        let log2n = vDSP_Length(log2(Float(n)))
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
