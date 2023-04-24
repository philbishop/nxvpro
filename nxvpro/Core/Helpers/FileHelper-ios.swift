//
//  FileHelper-ios.swift
//  nxvpro
//
//  Created by Philip Bishop on 24/04/2023.
//

import SwiftUI

extension FileHelper{
    //MARK: Storage notifications
    //global storage notification
    static var hasShowStorageAlert = false
    static func checkStorageLimits() ->Bool{
        
        if hasShowStorageAlert{
            return true
        }
        if FileHelper.hasExceededMediaLimit()  {
            AppLog.write("checkStorageLimits:hasExceededMediaLimite true")
            if FileHelper.hasStoargeSizeChanged() {
                AppLog.write("checkStorageLimits:hasStoargeSizeChanged true")
                hasShowStorageAlert = true
                
                let center = UNUserNotificationCenter.current()
            
                center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
                    if granted{
                          sendStorageAlert()
                        
                    }
                    
                }
                return false
            }
        }
        return true
    }
    static func testStorageAlert(){
        let center = UNUserNotificationCenter.current()
    
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted{
                 sendStorageAlert()
            }else{
                print("Local notifications disabled",error)
            }
        }
    }
    private static func sendStorageAlert(){
        let content = UNMutableNotificationContent()
        content.title = "NX-V Storage alert"
        content.body = "You have exceeded the limit you set for NX-V (local) storage"
        content.categoryIdentifier = "info"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
         
        let center = UNUserNotificationCenter.current()
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content,trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("Failed to add notification",error)
            }
        }
    }
}
