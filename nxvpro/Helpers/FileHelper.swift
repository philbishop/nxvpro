//
//  FileHelper.swift
//  NX-V
//
//  Created by Philip Bishop on 26/05/2021.
//

import Foundation
import ZIPFoundation

extension FileManager {

    enum ContentDate {
        case created, modified, accessed

        var resourceKey: URLResourceKey {
            switch self {
            case .created: return .creationDateKey
            case .modified: return .contentModificationDateKey
            case .accessed: return .contentAccessDateKey
            }
        }
    }
    func sortedContentsOfDirectory(atURL url: URL) -> [String]{
        do{
            let files =  try contentsOfDirectory(atURL: url, sortedBy: ContentDate.created)
        
            return files!
        }catch{
            
        }
        return [String]()
    }
    func contentsOfDirectory(atURL url: URL, sortedBy: ContentDate, ascending: Bool = true, options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]) throws -> [String]? {

        let key = sortedBy.resourceKey

        var files = try contentsOfDirectory(at: url, includingPropertiesForKeys: [key], options: options)

        try files.sort {

            let values1 = try $0.resourceValues(forKeys: [key])
            let values2 = try $1.resourceValues(forKeys: [key])

            if let date1 = values1.allValues.first?.value as? Date, let date2 = values2.allValues.first?.value as? Date {

                return date1.compare(date2) == (ascending ? .orderedAscending : .orderedDescending)
            }
            return true
        }
        return files.map { $0.lastPathComponent }
    }
}

extension URL {
    /// check if the URL is a directory and if it is reachable
    func isDirectoryAndReachable() throws -> Bool {
        guard try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            return false
        }
        return try checkResourceIsReachable()
    }

    /// returns total allocated size of a the directory including its subFolders or not
    func directoryTotalAllocatedSize(includingSubfolders: Bool = false) throws -> Int? {
        guard try isDirectoryAndReachable() else { return nil }
        if includingSubfolders {
            guard
                let urls = FileManager.default.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return nil }
            return try urls.lazy.reduce(0) {
                    (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0) + $0
            }
        }
        return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil).lazy.reduce(0) {
                 (try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    .totalFileAllocatedSize ?? 0) + $0
        }
    }

    /// returns the directory total size on disk
    func sizeOnDisk() throws -> String? {
        guard let size = try directoryTotalAllocatedSize(includingSubfolders: true) else { return nil }
        URL.byteCountFormatter.countStyle = .file
        guard let byteCount = URL.byteCountFormatter.string(for: size) else { return nil}
        return byteCount
    }
    private static let byteCountFormatter = ByteCountFormatter()
    
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }

    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}

class FileHelper{
    
    static let errLog = "nxv-err.log"
    static let stdoutLog = "nxv.log"
    
    static func getErrorLogPath(deleteExisting: Bool) -> String {
        return getFilePath(fname: errLog, deleteExisting: deleteExisting)
    }
    static func getLogPath(deleteExisting: Bool) -> String {
        return getFilePath(fname: stdoutLog, deleteExisting: deleteExisting)
    }
    static func getFilePath(fname: String,deleteExisting: Bool) -> String {
        let errorLogFile = getStorageRoot().appendingPathComponent(fname)
            
            if deleteExisting {
            if FileManager.default.fileExists(atPath: errorLogFile.path) {
                do{
                    try FileManager.default.removeItem(atPath: errorLogFile.path)
                }catch{}
            }
        }
        return errorLogFile.path
    }
    static func getPathForFilename(name: String) -> URL{
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        
        let url = URL(fileURLWithPath: documentsDirectory)
            
        
        return url.appendingPathComponent(name)
    }
    static func isV5Updgrade() -> Bool {
       let sr = getStorageRoot()
        let dataPath = sr.appendingPathComponent(".config")
        var isUpgrade = false
        if FileManager.default.fileExists(atPath: dataPath.path) {
            let oldDb = dataPath.appendingPathComponent("nvcc-v5.db")
            if FileManager.default.fileExists(atPath: oldDb.path) {
                isUpgrade = true
                print("Found old v5 .config dir")
                
                do {
                    try FileManager.default.removeItem(at: dataPath)
                        print("Deleted old v5 .config dir")
                }catch{
                    print("Failed to delete v5 .config dir")
                }
            }
        }
        return isUpgrade
    }
    static func getStorageRoot() ->URL{
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        
        let url = URL(fileURLWithPath: documentsDirectory)
        return url
    }
    static func getDownloadsDir() ->URL{
        let paths = NSSearchPathForDirectoriesInDomains(.downloadsDirectory, .userDomainMask, true)
        let downloadsDirectory = paths[0]
        
        let url = URL(fileURLWithPath: downloadsDirectory)
        return url
    }
    static func getUserSelectedVideoStorageDir() -> String? {
        let filePath = getPathForFilename(name: "vdir.txt")
        if FileManager.default.fileExists(atPath: filePath.path) {
            if let dirs = try? String(contentsOf: filePath, encoding: String.Encoding.utf8) {
                let lines = dirs.components(separatedBy: "\n")
                return lines[0]
            }
        }
        return nil
    }
    static func setUserSelectedVideoStorageDir(dirPath: String){
        let pathComponent = getPathForFilename(name: "vdir.txt")
        let data = dirPath+"\n"
        do {
            try data.write(to: pathComponent, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            print("FAILED TO SAVE DIR DATA",pathComponent.path)
        }
    }
    static func getTempVideoStorageRoot() -> URL {
        let storageRoot = getStorageRoot()
        let dataPath = storageRoot.appendingPathComponent("capture")
        
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                return dataPath
            } catch {
                return storageRoot
            }
        }
        return dataPath
    }
    static func getVideoStorageRoot() -> URL {
        
        let storageRoot = getStorageRoot()
        let dataPath = storageRoot.appendingPathComponent("video")
        
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                return dataPath
            } catch {
                return storageRoot
            }
        }
        return dataPath
    }
    static func getRemoteVideoStorageRoot() -> URL {
        
        let storageRoot = getStorageRoot()
        let dataPath = storageRoot.appendingPathComponent("rvideo")
        
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                return dataPath
            } catch {
                return storageRoot
            }
        }
        return dataPath
    }
    static func getVmdStorageRoot() -> URL {
        let storageRoot = getStorageRoot()
        let dataPath = storageRoot.appendingPathComponent("vmd")
        
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                return dataPath
            } catch {
                return storageRoot
            }
        }
        return dataPath
    }
    /*
    static func getVmdEventFilePath(filename: String,time: Date) -> URL{
        let vmdRoot = getVmdStorageRoot()
        let eventFile = filename + " " + getDateStr(date: time) + "_1.png"
        return vmdRoot.appendingPathComponent(eventFile)
    }
    static func getVmdTriggerEventFilePath(filename: String,time: Date) -> URL{
        let vmdRoot = getVmdStorageRoot()
        let eventFile = filename + " " + getDateStr(date: time) + ".png"
        return vmdRoot.appendingPathComponent(eventFile)
    }
    */
    static func getDateStr(date: Date) -> String{
       
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMddHHmmss"
        
        return fmt.string(from: date)
        
    }
    
    static func renameLastCapturedVideo(videoFileName: String,targetDir: URL,srcFile: String,callback: @escaping() -> Void){
        
        let validExt = ["mp4","avi","mov","webm","mjpg"]
        
        let q = DispatchQueue(label: "renameLastCapturedVideo")
        q.async {
          
            sleep(1)
            
            var matched = false
            let vsr = getTempVideoStorageRoot()
            print("VideoStorageRoot",vsr.path)
            do {
                let files = FileManager.default.sortedContentsOfDirectory(atURL: vsr)
                if  files.count == 0 {
                    return
                }
                //sort files by date
                
                var videoFiles = [String]()
                var videoExt = [String]()
                //iterate and find most recent video
                for i in 0...files.count-1 {
                    let file = files[i]
                    //get file ext, might not be MP4
                    let parts = file.components(separatedBy: ".")
                    
                    let ext = parts[parts.count-1]
                    let valid = validExt.contains(ext)
                    
                    if(!valid){
                        continue
                    }
                    //srcFile is IP Address to match to filename string
                    //vlc-record-2021-12-17-15h59m03s-rtsp___192.168.137.247_554_11
                    
                    if file.contains(srcFile){
                       
                        let vfn = videoFileName+"."+ext
                        print("VideoFileName",vfn)
                        
                        let storageRoot = targetDir
                        let srcPath = vsr.appendingPathComponent(file)
                        let vpath = storageRoot.appendingPathComponent(vfn)
                        
                        print("renameLastCapturedVideo",srcPath.path,vpath.path)
                        
                        matched = true
                        
                        try FileManager.default.moveItem(at: srcPath, to: vpath)
                        break
                    }
                }
            }
            catch{
                print("renameLastCapturedVideo /error/")
            }
            if !matched{
                print("renameLastCapturedVideo no match for",srcFile)
            }
        }
        
        DispatchQueue.main.async {
            callback()
        }
    }
    static func deleteMedia(cards: [CardData]){
        for cd in cards {
            do {
                try FileManager.default.removeItem(atPath: cd.filePath.path)
                if cd.hasFullsizeImagePath()  {
                    try FileManager.default.removeItem(atPath: cd.fullsizeImagePath!.path)
                }
            } catch {
                print("Delete event or video failed with error:\(error)")
            }
        }
    }
    static func exportCameraConfigs(cameras: [Camera]) -> URL?{
        
        var filesToExport = [URL]()
        let storageRoot = FileHelper.getStorageRoot()
        
        for cam in cameras{
            let ipa = cam.getDisplayAddr()
            let xml = storageRoot.appendingPathComponent(ipa + "_disco.xml")
            let json = storageRoot.appendingPathComponent(ipa + ".json")
            
            if FileManager.default.fileExists(atPath: xml.path) &&
                FileManager.default.fileExists(atPath: json.path){
                
                filesToExport.append(xml)
                filesToExport.append(json)
            }
            
        }
        
        let exportDir = storageRoot;
        
        //zip file
        let zipName = "nxv_wan_config-"+getDateStr(date: Date()) + ".nxvi"
        var archiveURL = URL(fileURLWithPath: exportDir.path)
        archiveURL.appendPathComponent(zipName)
        guard let archive = Archive(url: archiveURL, accessMode: .create) else  {
            return nil
        }
      
        for file in filesToExport{
            do {
                try archive.addEntry(with: file.lastPathComponent, relativeTo: file.deletingLastPathComponent())
            }catch{
                print("Adding entry to EXPORT WAN ZIP archive failed with error:\(error)")
                return nil
            }
        }
        //rename
        return archiveURL
    }
    static func exportFiles(cards: [CardData],mediaType: String) -> Bool{
            
        let exportDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        //zip files
        let zipName = "nxv_" + mediaType + "_export_"+getDateStr(date: Date()) + ".zip"
        var archiveURL = URL(fileURLWithPath: exportDir.path)
        archiveURL.appendPathComponent(zipName)
        guard let archive = Archive(url: archiveURL, accessMode: .create) else  {
            return false
        }
        
        for cd in cards {
            do {
                try archive.addEntry(with: cd.filePath.lastPathComponent, relativeTo: cd.filePath.deletingLastPathComponent())
                if cd.hasFullsizeImagePath() {
                    try archive.addEntry(with: cd.fullsizeImagePath!.lastPathComponent, relativeTo: cd.filePath.deletingLastPathComponent())
                }
            } catch {
                print("Adding entry to ZIP archive failed with error:\(error)")
                return false
            }
        }
        
        print("Export complete",archiveURL.path)
        
        return true
    }
    
    static func createTxtFile(name: String,contents: String) -> URL? {
        
        let pathComponent = FileHelper.getPathForFilename(name: name)
        
        do {
            try contents.write(to: pathComponent, atomically: true, encoding: String.Encoding.utf8)
            return pathComponent
        } catch {
            // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            print("FAILED TO CREATE TXT FILE",pathComponent.path)
        }
        return nil
    }
    
    static func getOnvifFiles() -> [URL] {
        
        var xmlFiles = [URL]()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: getStorageRoot().path)
            if files.count == 0 {
                return xmlFiles
            }
            for i in 0...files.count-1 {
                let file = files[i]
               
                let parts = file.components(separatedBy: ".")
                
                let ext = parts[parts.count-1]
                
                if ext == "xml" {
                    xmlFiles.append( getPathForFilename(name: file))
                }
            }
        }catch{
            print("getOnvifFiles failed with error:\(error)")
        }
        
        return xmlFiles
    }
    static func getOnvifFilesFor(camera: Camera) -> [URL]{
        var xmlFiles = [URL]()
        
        let fileTag = camera.getBaseFileName()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: getStorageRoot().path)
            if files.count == 0 {
                return xmlFiles
            }
            for i in 0...files.count-1 {
                let file = files[i]
        
                if file.hasPrefix(fileTag){
                
                    let parts = file.components(separatedBy: ".")
                    
                    let ext = parts[parts.count-1]
                    
                    if ext == "xml" {
                        xmlFiles.append( getPathForFilename(name: file))
                    }
                }
            }
        }catch{
            print("getOnvifFiles(forCamera: failed with error:\(error)")
        }
        return xmlFiles
    }
    static func deleteCamera(camera: Camera){
        let basefileName = camera.getBaseFileName()
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: getStorageRoot().path)
        
            for file in files{
                if file.hasPrefix(basefileName){
                    let fp = getPathForFilename(name: file)
                    do{
                        
                        try FileManager.default.removeItem(atPath: fp.path)
                            print("Deleted",file)
                    }catch{
                        print("FAILED TO DELETE",file)
                    }
                }
            }
        }catch{
            print("deleteCamera failed with error:\(error)")
        }
    }
    static func deleteAll(){
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()
        dictionary.keys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: getStorageRoot().path)
        
            for file in files{
                
                let parts = file.components(separatedBy: ".")
                
                let ext = parts[parts.count-1]
                
                if ext == ".log" {
                    continue
                }
                do{
                    let fPath = getPathForFilename(name: file)
                    try FileManager.default.removeItem(at: fPath)
                        print("deleted",file)
                }catch{
                    print("deleteAll failed on",file)
                }
            }
            let vDir = getVideoStorageRoot()
            try FileManager.default.removeItem(at: vDir)
                print("Deleted",vDir)
            
            let rvDir = getRemoteVideoStorageRoot()
            try FileManager.default.removeItem(at: rvDir)
                print("Deleted",rvDir)
            
            let sdDir = getSdCardStorageRoot()
            try FileManager.default.removeItem(at: sdDir)
                print("Deleted",sdDir)
            
            
            let mDir = getVmdStorageRoot()
            try FileManager.default.removeItem(at: mDir)
                print("Deleted",mDir)
            
        }catch{
            print("DeleteAll failed with error:\(error)")
        }
    }
    static func purgeOldRemoteVideos(){
        let dq = DispatchQueue(label: "purge_rv")
        dq.async {
            FileHelper.purgeOldRemoteVideosImp()
        }
    }
    static private func purgeOldRemoteVideosImp(){
        let sd = getRemoteVideoStorageRoot()
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: sd.path)
        
            for file in files{
                let furl = sd.appendingPathComponent(file)
                if let atts = furl.attributes{
                    if let lastModified = atts[FileAttributeKey.modificationDate] as? Date{
                        //check is not today
                        let now = Date()
                        let diffSecs = lastModified.distance(to: now)
                        let diff = diffSecs /  (60 * 60)
                        print("purgeOldRemoteVideosImp dif",diff)
                        if diff > 2{
                            //delete file
                            print("purgeOldRemoteVideosImp > 8 hors",lastModified)
                            do{
                                try FileManager.default.removeItem(at: furl)
                                print("purgeOldRemoteVideosImp deleted",file)
                            }catch{
                                print("purgeOldRemoteVideosImp failed to delete",file)
                            }
                        }
                        
                    }
                }
            }
        }catch{
            print("purgeOldRemoteVideosImp failed with error:\(error)")
        }
    }
    static func deleteAllMedia(){
        do {
            let vDir = getVideoStorageRoot()
            try FileManager.default.removeItem(at: vDir)
                print("Deleted",vDir)
            
        }catch{
            print("DeleteAllMedia failed with error:\(error)")
        }
    }
    static func removeIllegalChars(str: String) -> String {
        var camName = str
        camName = camName.replacingOccurrences(of: ":", with: "")
        camName = camName.replacingOccurrences(of: ".", with: "")
        camName = camName.replacingOccurrences(of: "/", with: "")
        return camName
    }
    
    //MARK: Used to move dynamic IP camera's last thumb to new IP file
    static func moveCameraFile(src: String,dest: String){
        do {
            let rootDir = getStorageRoot()
            let srcFile = rootDir.appendingPathComponent(src)
            let destFile = rootDir.appendingPathComponent(dest)
            
            try FileManager.default.moveItem(at: srcFile, to: destFile)
                print("moveCameraFile",src)
        }
        catch{
            print("moveCameraFile failed with error:\(error)")
        }
    }
    static var disableDelete = false
    static func deleteCameraFiles(camToDelete: Camera)
    {
        
        let tag = camToDelete.getDisplayAddr()
        //delete all files starting with tag
       
        if disableDelete{
            print("deleteCameraFiles->disabled",tag)
            return
        }
        print("deleteCameraFiles",tag)
        
        let sroot = getStorageRoot()
        //delete json file
        let jFile = camToDelete.getJFileName()
        let jPath = sroot.appendingPathComponent(jFile)
        do{
            try FileManager.default.removeItem(at: jPath)
                print("deleteCameraFiles OK",jPath.path)
        }catch{
            print("Failed to delete json file",jPath.path)
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: sroot.path)
            if  files.count == 0 {
                return
            }
            //iterate and find most recent video
            for i in 0...files.count-1 {
                let file = files[i]
                
                if file.hasPrefix(tag){
                    let fpath = sroot.appendingPathComponent(file)
                    do{
                        try FileManager.default.removeItem(at: fpath)
                        print("Deleted file",file)
                    }catch{
                      print("Failed to delete file",fpath.path)
                    }
                }
            }
        }catch{
            print("Failed to delete camera files",tag)
        }
    }
    
    //MARK: Port scanner know ONVIF Ports
    static func getKnownPorts() -> [String]{
        var ports = [String]()
        
        let fileName = "ports"
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                let trimmed = contents.trimmingCharacters(in: NSCharacterSet.newlines)
                ports = trimmed.components(separatedBy: ",")
            } catch {
                print("Failed to load file from bundle",fileName)
            }
        }
        
        let portsFile = getStorageRoot().appendingPathComponent("ports.txt")
        if FileManager.default.fileExists(atPath: portsFile.path){
            do{
                let contents = try String(contentsOfFile: portsFile.path)
                let trimmed = contents.trimmingCharacters(in: NSCharacterSet.newlines)
                ports = trimmed.components(separatedBy: ",")
            }catch{
                print("FileHelper unable to load ports.txt")
            }
        }
        
        
        return ports
    }
    static func cameraExists(host: String,port: UInt16) -> Bool{
        let discoXml = host + "_" + String(port) + "_disco.xml"
        let discoPath = getPathForFilename(name: discoXml)
        let exists = FileManager.default.fileExists(atPath: discoPath.path)
        return exists
    }
    
    static func getSdCardStorageRoot() -> URL{
        let storageRoot = getStorageRoot()
        let dataPath = storageRoot.appendingPathComponent("sdcache")
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                return dataPath
            } catch {
                return storageRoot
            }
        }
        return dataPath

    }
    static func toValidFileName(str: String) -> String{
        let badChars = ["@","[","]"]
        var goodString = str
        for c in badChars{
            goodString = goodString.replacingOccurrences(of: c, with: "_")
        }
        
        return goodString
    }
    //MARK: SMB
    static func getMountStorageRoot() -> URL{
        let storageRoot = getStorageRoot()
        let dataPath = storageRoot.appendingPathComponent("mount")
        if !FileManager.default.fileExists(atPath: dataPath.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataPath.path, withIntermediateDirectories: true, attributes: nil)
                return dataPath
            } catch {
                return storageRoot
            }
        }
        return dataPath
        
    }
    
    //MARK: Export Cmare, Map, Group Settings
    
    //all cameras listed as discovered
    static func exportGroupSettings(cameraGroups: CameraGroups) -> String{
        var buf = ""
        for grp in cameraGroups.flatGroups{
            buf.append(grp)
            buf.append("\n")
        }
        return buf
    }
    static func exportWanSettings(cameras: [Camera]) -> String{
        var buf = ""
        
        for cam in cameras{
            
            let hostAndPort = cam.getHostAndPort()
            if hostAndPort.count == 2{
                buf.append(String(format: "%@:%@|%@|%@|%@", hostAndPort[0],hostAndPort[1],cam.user,cam.password,cam.getDisplayName()))
                buf.append("\n")
            }
        }
        return buf
    }
    
    static func exportMapSettings(cameras: [Camera]) -> String{
        
        var buf = ""
        
        for cam in cameras{
            cam.loadLocation()
            if cam.hasValidLocation(){
                if let loc = cam.location{
                    
                    buf.append(String(format: "%@ %@ %f %f", cam.getStringUid(), String(cam.beamAngle), loc[0], loc[1]))
                    buf.append("\n")
                }
                
            }
        }
        return buf
        
    }
}
