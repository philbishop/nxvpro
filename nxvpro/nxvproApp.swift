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

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        print("AppDelegate:supportedInterfaceOrientationsFor")
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            return  UIInterfaceOrientationMask.portrait
        }
        return UIInterfaceOrientationMask.all
    }
    #if DEBUG
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                didReceive response: UNNotificationResponse,
                withCompletionHandler completionHandler:
                                @escaping () -> Void) {
        // Get the meeting ID from the original notification.
        let userInfo = response.notification.request.content.userInfo
        
        print("AppDelegate got push")
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler:
                                 @escaping (UNNotificationPresentationOptions) -> Void) {
        
       
    }
    
    /// This function made for handling push notifications when app running (both states active or inactive)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        
        /// Hide badge number if it exist
        application.applicationIconBadgeNumber = 0
        
        print("AppDelegate got push !!!")
        
        /// Get user your data from userInfo dictionary if you need
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let title = alert["title"] as? String,
              let body = alert["body"] as? String else {
                print("[AppDelegate] - Warning: user info missing aps or other data.")
            return
        }
        
       /// Check current application state
       if UIApplication.shared.applicationState == .active {
          // Your app in foreground, you can ask user to want to take action about what you want to do.
       } else {
          // Your app in background at most in inactive mode, user when taps on notification alert app will become active so you can do whatever you want directly
       }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("AppDelegate:didFailToRegisterForRemoteNotificationsWithError",error)
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("AppDelegate:didRegisterForRemoteNotificationsWithDeviceToken")
        let tokenStr = deviceToken.hexString()
        
        print(tokenStr)
        
        cloudStorage.updateDeviceToken(deviceName: UIDevice.current.name, deviceToken: tokenStr)
        //print("AppDelegate:deviceToken",tokenStr)
        /*
        if let dStr = String(data: deviceToken,encoding: .utf8){
            print("AppDelegate:deviceToken",dStr)
        }
          */
        
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
            
            // If granted comes true you can enabled features based on authorization.
            guard granted else { return }
            
            DispatchQueue.main.async{
                application.registerForRemoteNotifications()
            }
        }
        center.delegate = self
        
        
       return true
    
        print("AppDelegate:didFinishLaunchingWithOptions")
        return true
    }
    #endif
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
