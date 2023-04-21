//
//  main.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 6/3/23.
//

import Foundation
import ArgumentParser

@main
struct PerfAnalysisRunner: ParsableCommand {
    @Option(name: .shortAndLong, help: "Directory with dSYMs")
    var dsyms: String? = nil
    
    @Flag(name: .shortAndLong, help: "Relaunch app with profiling from startup.")
    var launch = false

    @Flag(name: .shortAndLong, help: "Use simulator")
    var simulator: Bool = false
  
    @Flag(name: .shortAndLong, help: "Verbose logging")
    var verbose: Bool = false

    mutating func run() throws {
      if let dsym = dsyms, dsym.hasSuffix(".dSYM") {
        PerfAnalysisRunner.exit(withError: ValidationError("The dsym argument should be set to a folder containing your dSYM files, not the dSYM itself"))
      }
        let helper = RunnerHelper(dsyms, launch, simulator, verbose)
        Task {
            do {
                try await helper.start()
            } catch let error {
                print("ETTrace error: \(error)")
            }
            PerfAnalysisRunner.exit()
        }
        
        RunLoop.main.run()
    }
}
