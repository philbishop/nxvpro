//
//  nxvproApp.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI
import Foundation

var syncService = NxvProSyncClient()
//MARK: Zero Config Sync Service
var zeroConfigSyncService: NxvProSyncService?
var zeroConfigSyncHandler = NxvProSynHandler();
var cloudStorage = CloudStorage()
var videoViewFactory: VlcVideoViewFactory?

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return  UIInterfaceOrientationMask.portrait
        }
        return UIInterfaceOrientationMask.all
    }
}

@main
struct nxvproApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var monitor = NetworkMonitor.shared
    
    var body: some Scene {
        WindowGroup {
            NxvProContentView().onAppear{
               syncService.startDiscovery()
                nxvproApp.startZeroConfig()
                cloudStorage.checkIcloudAvailable()
                videoViewFactory = VlcVideoViewFactory.getInstance()
                
            }
        }
    }
    static func startZeroConfig(){
        if zeroConfigSyncService == nil{
            AppLog.write("nxvproApp:startZeroConfig -> Starting sync service")
            zeroConfigSyncService = NxvProSyncService()
            zeroConfigSyncService?.listener = zeroConfigSyncHandler
            zeroConfigSyncService!.start()
        }
    }
    static func stopZeroConfig(){
        if zeroConfigSyncService != nil{
            
            zeroConfigSyncService!.stop()
            zeroConfigSyncService = nil
            AppLog.write("nxvproApp:startZeroConfig -> Stopped sync service")
        }
    }
}
