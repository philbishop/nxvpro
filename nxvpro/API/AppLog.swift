//
//  AppLog.swift
//  NX-V
//
//  Created by Philip Bishop on 18/06/2021.
//

import Foundation

class AppLog{
    
    private static var fmt = DateFormatter()
    private static var initialized: Bool = false
    
    
    
    static func write(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if items.count == 0 {
            print()
            return
        }
        if !initialized {
            fmt.dateFormat = "dd-MM-yyyy HH:mm:ss"
            initialized = true
            
            #if !DEBUG
                let errorLogFile = FileHelper.getErrorLogPath(deleteExisting: true)
                
                freopen(errorLogFile, "a", stderr)
                
                let logFile = FileHelper.getLogPath(deleteExisting: true)
                
                freopen(logFile, "a", stdout)
                
                //NOTE: Before sending log files use
                //  fflush(stdout)
            #endif
        }
        let date = fmt.string(from: Date())
        print(date+" ", terminator: "")
        print(items,separator: separator,terminator: terminator)
        
    }
    private static var loggedCameras: [String: Bool] = [:]
    
    static func dumpCamera(camera: Camera)
    {
        if camera.isNvr(){
            if let alreadyDumped = loggedCameras[camera.getDisplayAddr()] {
                return
            } else {
                loggedCameras[camera.getDisplayAddr()] = true
                var logItems = [String]()
                logItems.append("NVR,"+camera.getDisplayAddr())
                let props = camera.getProperties()
                for prop in props{
                    logItems.append(prop.0+","+prop.1)
                }
                for vcam in camera.vcams{
                    logItems.append("VCAM,"+vcam.getDisplayName())
                    let props = vcam.getProperties()
                    for prop in props{
                        logItems.append(prop.0+","+prop.1)
                    }
                }
                let csvFile = "nvr_"+camera.getDisplayAddr()+".csv"
                let csvFilePath = FileHelper.getPathForFilename(name: csvFile)
                
                let joined = logItems.joined(separator: "\n")
                do {
                    try joined.write(toFile: csvFilePath.path, atomically: true, encoding: .ascii)
                } catch {
                    // handle error
                }
            }
        }
    }
}
