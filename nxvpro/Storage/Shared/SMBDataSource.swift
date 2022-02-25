//
//  SMBDataSource.swift
//  NX-V
//
//  Created by Philip Bishop on 01/02/2022.
//

//import Cocoa
//import NetFS
import Foundation

class SMBDataSource{
    
    var camera: Camera?
    var scheme = "smb"
    var folders = [String]()
    
    init(scheme: String){
        self.scheme = scheme
    }
    /*
    func mount(camera: Camera,host: String,user: String,password: String) -> Bool{
        self.camera = camera
        self.folders.removeAll()
        
        var uc = URLComponents()
        uc.scheme = scheme
        uc.path = "/"
        uc.host = host
        uc.user = user
        uc.password = password
        //uc.host = "192.168.137.199"
       //uc.user = "nxv_ftp"
        //uc.password = "Inc@X2022Nxv"
        let url = uc.url!
        print(url)
        let curl = url as? CFURL
        
        let mountName = camera.storageSettings.path.replacingOccurrences(of: "/", with: "")
        
        let localDir = FileHelper.getMountStorageRoot()
        let localMountDir = localDir.appendingPathComponent(mountName)
        
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey]
        let paths = FileManager().mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [])
        if let urls = paths {
            for url in urls {
                let components = url.pathComponents
                if components.count > 1
                    && url.path.contains(localMountDir.path)
                {
                    print(url)
                    getFolders(localDir)
                    return true
                }
            }
        }
        
        let result = NetFSMountURLSync(curl, localDir as CFURL, nil, nil, nil, nil, nil)
    
        if result == 0 {
            getFolders(localDir)
            return true
        }
        return false
    }
     */
    func getFolders(_ mountDir: URL) -> [String]{
        folders.removeAll()
        if let enumerator = FileManager.default.enumerator(at: mountDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys:[.isDirectoryKey])
                    if fileAttributes.isDirectory! {
                        folders.append(fileURL.lastPathComponent)
                    }
                }
                catch{
                }
            }
        }
        return folders
    }
    func getFiles(_ mountDir: URL,fileExt: String,date: Date) -> [RecordToken]{
        var frmt = DateFormatter()
        frmt.dateFormat="dd MM yyyy HH:mm:ss"
       
        var files = [RecordToken]()
        if let enumerator = FileManager.default.enumerator(at: mountDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys:[.isRegularFileKey])
                    if fileAttributes.isRegularFile! {
                        if fileURL.path.hasSuffix(fileExt){
                            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey,.contentModificationDateKey])
                            let fileSize = resourceValues.fileSize!
                            let modified = resourceValues.contentModificationDate
                            if fileSize > 0 && Calendar.current.isDate(date, inSameDayAs: modified!){
                                
                                let rc = RecordToken()
                                rc.localFilePath = fileURL.path
                                rc.ReplayUri = fileURL.path
                                rc.storageType = .smb
                                rc.Token = "FTP" // generic flag for remote storage
                                rc.fileDate = modified
                                rc.Time = frmt.string(from: modified!)
                                files.append(rc)
                            }
                        }
                    }
                } catch { print(error, fileURL) }
            }
            print(files)
            
        }
        return files
    }
    
    
}
