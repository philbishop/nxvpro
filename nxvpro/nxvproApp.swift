//
//  nxvproApp.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI

var syncService = NxvProSyncClient()
//MARK: Zero Config Sync Service
var zeroConfigSyncService: NxvProSyncService?
var zeroConfigSyncHandler = NxvProSynHandler();

@main
struct nxvproApp: App {
    var monitor = NetworkMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            NxvProContentView().onAppear{
               syncService.startDiscovery()
                nxvproApp.startZeroConfig()
            }
        }
    }
    
    static func startZeroConfig(){
        if zeroConfigSyncService == nil{
            print("nxvproApp:startZeroConfig -> Starting sync service")
            zeroConfigSyncService = NxvProSyncService()
            zeroConfigSyncService?.listener = zeroConfigSyncHandler
            zeroConfigSyncService!.start()
        }
    }
    static func stopZeroConfig(){
        if zeroConfigSyncService != nil{
            print("nxvproApp:startZeroConfig -> Stopping sync service")
            zeroConfigSyncService!.stop()
            zeroConfigSyncService = nil
        }
    }
}
