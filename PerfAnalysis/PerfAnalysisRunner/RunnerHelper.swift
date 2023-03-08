//
//  RunnerHelper.swift
//  PerfAnalysisRunner
//
//  Created by Itay Brenner on 8/3/23.
//

import Foundation
import PeerTalk
import CommunicationFrame
import Swifter

class RunnerHelper: NSObject, PTChannelDelegate {
    let dsyms: String?
    let bundleId: String
    let launch: Bool
    let uuid: String?
    
    lazy var channel = PTChannel(protocol: nil, delegate: self)
    var server: HttpServer? = nil
    var reportGenerated: Bool = false
    
    init(_ dsyms: String?, _ bundleId: String, _ launch: Bool, _ uuid: String?) {
        self.dsyms = dsyms
        self.bundleId = bundleId
        self.launch = launch
        self.uuid = uuid
    }
    
    func channel(_ channel: PTChannel, didRecieveFrame type: UInt32, tag: UInt32, payload: Data?) {
        if type == PTFrameTypeReportCreated {
            reportGenerated = true
        }
    }
    
    func channelDidEnd(_ channel: PTChannel, error: Error?) {
        print("Device disconnected")
        exit(1)
    }
    
    func start() async throws {
        print("Please open the app on the simulator / device.")
        print("Press any key when ready...")
        _ = readLine()

        print("Connecting to device.")

        let deviceManager: DeviceManager = uuid != nil ? SimulatorDeviceManager(deviceUuid: uuid!) : PhysicalDevicemanager()

        try await deviceManager.connect(with: channel)

        try await deviceManager.sendStartRecording(launch, channel)

        if launch {
            print("Re-launch the app to start recording, then press any key to exit")
        } else {
            print("Started recording, press any key to exit")
        }

        _ = readLine()
        print("            \r")

        try await deviceManager.sendStopRecording(channel)

        while(!reportGenerated) {
            usleep(10)
        }

        let localFolder = Bundle.main.bundlePath
        let outFolder = "\(localFolder)/tmp/emerge-perf-analysis"
        try FileManager.default.createDirectory(atPath: outFolder, withIntermediateDirectories: true)

        try deviceManager.copyFromDevice(bundleId: bundleId, source: "/Documents/emerge-output/output.json", destination: outFolder)
        
        let outputPath = "\(outFolder)/Documents/emerge-output/output.json"
        if !FileManager.default.fileExists(atPath: outputPath) {
            print("File not found")
            exit(1)
        }
        
        print("Stopped recording, symbolicating...")
        
        let jsonData = try String(contentsOfFile: outputPath).data(using: .utf8)
        let responseData = try JSONDecoder().decode(ResponseModel.self, from: jsonData!)
        
        let isSimulator = responseData.isSimulator
        var arch = responseData.cpuType.lowercased()
        if arch == "arm64e" {
            arch = " arm64e"
        } else {
            arch = ""
        }
        var osVersion = responseData.osBuild
        osVersion.removeAll(where: { !$0.isLetter && !$0.isNumber })
        
        let symbolicator = Symbolicator(isSimulator: isSimulator, dSymsDir: dsyms, osVersion: osVersion, arch: arch)
        let syms = symbolicator.symbolicate(responseData.stacks, responseData.libraryInfo.loadedLibraries)
        let flamegraph = FlamegraphGenerator.generateFlamegraphs(stacks: responseData.stacks, syms: syms) as NSDictionary
        
        let outJsonData = try JSONSerialization.data(withJSONObject: flamegraph, options: .withoutEscapingSlashes)
        let jsonString = String(data: outJsonData, encoding: String.Encoding.ascii)
        try jsonString?.write(toFile: "output.json", atomically: true, encoding: .utf8)
        
        try startLocalServer(outJsonData)
        let url = URL(string: "https://emergetools.com/flamegraph")!
        NSWorkspace.shared.open(url)
        
        _ = readLine()
    }
    
    func startLocalServer(_ data: Data) throws {
        server = HttpServer()
        
        let headers = [
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Headers": "baggage,sentry-trace"
        ]
        
        server?["/output.json"] = { a in
            if a.method == "OPTIONS" {
                return .raw(204, "No Content", [
                    "Access-Control-Allow-Methods": "GET",
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Headers": "baggage,sentry-trace"
                ], nil)
            }
            
            return .raw(200, "OK", headers, { writter in
                try? writter.write(data)
                exit(0)
            })
        }
        try server?.start(37577)
    }
}
