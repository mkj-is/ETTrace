//
//  Sample.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 7/3/23.
//

import Foundation

class Sample {
    let stack: [Any]
    var time: Double
    
    init(time: Double, stack: [Any]) {
        self.time = time
        self.stack = stack
    }
    
//    func createCopy() -> Sample {
//        return Sample(time: self.time, stack: self.stack)
//    }
    
    var description: String {
        let timeStr = String(format: "%.15f", self.time).replacingOccurrences(of: "0*$", with: "", options: .regularExpression)
        let stackStr = stack.map { s in
            if let array = s as? Array<Any> {
                return "\(array[0])"
            }
            return "\(s)"
        }.joined(separator: ";")
        return "\(stackStr) \(timeStr)"
    }
}

class MemorySample {
    let stack: [Any]
    var memory: UInt64
    
    init(memory: UInt64, stack: [Any]) {
        self.memory = memory
        self.stack = stack
    }
    
    var description: String {
        let stackStr = stack.map { s in
            if let array = s as? Array<Any> {
                return "\(array[1])" // Position 0 is library, 1 is method
            }
            return "\(s)"
        }.joined(separator: ";")
        return "\(stackStr) \(memory)"
    }
}
