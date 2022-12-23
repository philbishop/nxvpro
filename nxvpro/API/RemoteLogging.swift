//
//  RemoteLogging.swift
//  NX-V
//
//  Created by Philip Bishop on 09/06/2021.
//

import SwiftUI

class RemoteLogging{
#if DEBUG_X
    static let loggingHost = "http://192.168.137.1/CloudGlu/DeviceProxyHandler.ashx"
    #else
        static let loggingHost = "https://incax.com/CloudGlu/DeviceProxyHandler.ashx"
    #endif
    private static var APP_VER = Bundle.main.infoDictionary?["CFBundleShortVersionString"]
    private static var lastItem = ""
    
    static func log(item: String){
        
        if item == lastItem {
            return
        }
        
        lastItem = item
        
        #if !DEBUG
        
        let ver = APP_VER as? String
        var osv = UIDevice.current.systemVersion
        let deviceModel = unameMachine
        if deviceModel.isEmpty == false{
            osv = osv + " " + deviceModel;
        }
        let logItem = ver! + " (" + osv + ") " + item;
       
        let device = ProcessInfo.processInfo.isiOSAppOnMac ? "iosMac" : "iPad"
        let endpoint = loggingHost + "?xop=nxlog&xapp=NXV-PRO_" + device
        
        let apiUrl = URL(string: endpoint)!
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        try request.httpBody = logItem.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                return
            }
            
        }
        task.resume()
        
        #endif
        
        AppLog.write(item)
    }
    static var unameMachine: String {
        var utsnameInstance = utsname()
        uname(&utsnameInstance)
        let optionalString: String? = withUnsafePointer(to: &utsnameInstance.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return optionalString ?? ""
    }
}
