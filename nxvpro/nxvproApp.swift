//
//  nxvproApp.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI

var syncService = NxvProSyncService()

@main
struct nxvproApp: App {
    var monitor = NetworkMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            NxvProContentView().onAppear{
               syncService.startDiscovery()
            }
        }
    }
}
