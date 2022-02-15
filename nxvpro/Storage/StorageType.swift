//
//  StorageTypes.swift
//  NX-V
//
//  Created by Philip Bishop on 29/01/2022.
//

import Foundation

class StorageSettings : Codable {
    var storageType = ""
    var host = ""
    var port = ""
    var user = ""
    var password = ""
    var path = ""
    var fileExt = ""
    var xtras = [String]()
    var authenticated = false
    
    enum CodingKeys: String, CodingKey {
        case storageType = "storageType"
        case host = "host"
        case port = "port"
        case user = "user"
        case password = "password"
        case path = "path"
        case fileExt = "fileExt"
        case xtras = "xtras"
        case authenticated = "authenticated"
    }

}

enum StorageType{
    case onboard,ftp,smb,nfs
    
    var description : String {
        switch self {
        case .onboard: return "onboard"
        case .ftp: return "ftp"
        case .smb: return "nas/smb"
        case .nfs: return "nas/nfs"
            
        }
    }
}

class StorageHelper{
    static func getRemoteCacheFilePath(camera: Camera,searchDate: Date,storageType: StorageType) -> URL{
        let startOfOay = Calendar.current.startOfDay(for: searchDate)
        
        let sdCardRoot = FileHelper.getSdCardStorageRoot()
        var frmt = DateFormatter()
        frmt.dateFormat="yyyyMMdd"
        let dayStr =  frmt.string(from: startOfOay)
        let camUid = camera.isVirtual ? camera.getBaseFileName() : camera.getStringUid()
        let filename = camUid + "_" + storageType.description + "_" +  dayStr + ".csv"
        let saveToPath = sdCardRoot.appendingPathComponent(filename)
        return saveToPath
    }
    static func getLocalFilePath(remotePath: String) -> (URL,Bool){
        let targetDir = FileHelper.getVideoStorageRoot()
        let fparts = remotePath.components(separatedBy: "/")
        let np = fparts.count
        var fname = np == 1 ? remotePath : fparts[np-1]
        fname = FileHelper.toValidFileName(str: fname)
        
        let targetUrl = targetDir.appendingPathComponent(fname)
        let exists = FileManager.default.fileExists(atPath: targetUrl.path)
        return (targetUrl,exists)
    }
    
}
