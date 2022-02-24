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
                if zeroConfigSyncService == nil{
                    print("AppDelegate:startZeroConfigService -> Starting sync service")
                    zeroConfigSyncService = NxvProSyncService()
                    zeroConfigSyncService?.listener = zeroConfigSyncHandler
                    zeroConfigSyncService!.start()
                }
            }
        }
    }
}
