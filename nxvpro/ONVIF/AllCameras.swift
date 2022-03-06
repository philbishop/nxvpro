//
//  AllCameras.swift
//  NX-V
//
//  Created by Philip Bishop on 13/06/2021.
//

import Foundation

//MARK: all the cameras ever found and stored on the file system
class AllCameras{
    
    var cameras: [Camera]
    let lock = NSLock()
    
    init(){
        cameras = [Camera]()
    }
    func reset()
    {
        lock.lock()
        cameras.removeAll()
        lock.unlock()
    }
    func getNotDiscovered(discoCams: [Camera]) -> [Camera]{
        var notFound = [Camera]()
        lock.lock()
        for cam in cameras {
            if isDiscovered(camera: cam, discoCams: discoCams) == false {
                
                    notFound.append(cam)
                
            }
        }
        lock.unlock()
        return notFound
    }
    func isDiscovered(camera: Camera, discoCams: [Camera]) -> Bool {
        for cam in discoCams {
            if cam.xAddr == camera.xAddr {
                return true
            }
        }
        return false
    }
    var upgradeComplete = false
    private func upgradeFilenames(){
        let fileTag = "_disco.xml"
        let storageRoot = FileHelper.getStorageRoot()
        do {
             let files = try FileManager.default.contentsOfDirectory(atPath: storageRoot.path)
            
            if files.count == 0 {
                return
            }
            for i in 0...files.count-1 {
                let file = files[i]
            
                if file.hasSuffix(fileTag) == false {
                    continue
                }
                
                let parts = file.components(separatedBy: "_")
                
                let ipa = parts[0]
                
                if parts.count == 2{
                    let discoPath = FileHelper.getPathForFilename(name: ipa + "_disco.xml")
                    
                    let xml = try String(contentsOf: discoPath)
                    let data = xml.data(using: .utf8)
                    
                    let parser = DiscoveryParser()
                    parser.parseRespose(xml: data!)
                    
                    let tmpCam = Camera(id: 0);
                    tmpCam.xAddr = parser.xAddr;
                    renameFiles(oldIp: ipa,newName: tmpCam.getBaseFileName());
                }
            }
        }catch{
            print("AllCameras:upgradeFilenames: \(error)")
        }
    
    }
    private func renameFiles(oldIp: String, newName: String){
        //iter through all files that start with oldIp
        let storageRoot = FileHelper.getStorageRoot()
        do {
             let files = try FileManager.default.contentsOfDirectory(atPath: storageRoot.path)
            
            if files.count == 0 {
                return
            }
            for i in 0...files.count-1 {
                let file = files[i]
                
                if file.hasPrefix(oldIp){
                    let oldPath = storageRoot.appendingPathComponent(file)
                    let newFile = file.replacingOccurrences(of: oldIp, with: newName)
                    let newFilePath = storageRoot.appendingPathComponent(newFile)
                    if FileManager.default.fileExists(atPath: newFilePath.path) == false {
                        do{
                            try FileManager.default.moveItem(atPath: oldPath.path, toPath: newFilePath.path)
                                print("renamed file",file,newFile)
                        }
                        catch{
                            print("AllCameras:rename file: \(error)",file)
                        }
                    }
                }
            }
        }catch{
            print("AllCameras:renameFiles: \(error)")
        }
    }
    func loadFromXml(){
        
        if(!upgradeComplete){
            
            upgradeFilenames()
            upgradeComplete = true;
        }
        
        
        //192.168.0.9_disco.xml
        let fileTag = "_disco.xml"
        let storageRoot = FileHelper.getStorageRoot()
        do {
             let files = try FileManager.default.contentsOfDirectory(atPath: storageRoot.path)
            
            if files.count == 0 {
                return
            }
            lock.lock()
            
            cameras.removeAll()
            for i in 0...files.count-1 {
                let file = files[i]
            
                if file.hasSuffix(fileTag) == false {
                    continue
                }
                
                let parts = file.components(separatedBy: "_")
                
                let ipa = parts[0]
                let discoPath = FileHelper.getPathForFilename(name: file)
                
                let camera = Camera(id: cameras.count)
                camera.xAddr = ipa
                do {
                    if FileManager.default.fileExists(atPath: discoPath.path) {
                       
                        let xml = try String(contentsOf: discoPath)
                        let data = xml.data(using: .utf8)
                        
                        let parser = DiscoveryParser()
                        parser.parseRespose(xml: data!)
                        if parser.urn.isEmpty == false{
                            //print("AllCameras;urn",camera.xAddr,parser.urn)
                            camera.wsaAddr = parser.urn
                        }
                        if parser.xAddr.isEmpty == false{
                            camera.xAddr = parser.xAddr
                            camera.name = parser.camName
                            camera.id = cameras.count
                            camera.loadCredentials()
                            
                            populateCamera(camera: camera)
                            
                            cameras.append(camera);
                            
                        }
                        
                        //addCamera(: ipa)
                    }
                
                    
                }
                catch{
                    print("AllCameras:loadFromXml add camera: \(error)")
                }
                
                print("AllCameras: ",ipa)
            }
            lock.unlock()
        }
        catch{
            print("AllCameras:loadFromXml: \(error)")
        }
        
    }
    func checkWasAddr(addr1: String,addr2: String) -> Bool{
        #if WASADDR_ENABLE
            let p1 = addr1.components(separatedBy: "-")
            let p2 = addr2.components(separatedBy: "-")
            for i in 0...2{
                if p1[i] != p2[i]{
                    return false
                }
            }
            return true
        #else
        return false
        #endif
    }
    
    func getExistingCamera(discoCamera: Camera) -> Camera{
        var camIndex = 0;
        var camToDelete: Camera?
        lock.lock()
        for cam in cameras{
            if cam.isNvr() || cam.isVirtual{
                continue
            }
            if checkWasAddr(addr1: cam.wsaAddr, addr2: discoCamera.wsaAddr){
                if cam.loadCredentials() && cam.user.isEmpty==false && cam.xAddr.isEmpty != false{
                    if cam.getDisplayAddr() != discoCamera.getDisplayAddr(){
                        discoCamera.user = cam.user
                        discoCamera.displayName = cam.displayName
                        discoCamera.password = cam.password
                        discoCamera.profiles = cam.profiles
                        
                        //copy / move .png for existing
                        FileHelper.moveCameraFile(src: cam.thumbName(),dest: discoCamera.thumbName())
                        FileHelper.deleteCameraFiles(camToDelete: cam)
                        
                        camToDelete = cam
                        break
                    }
                    
                }
                
            }
            camIndex += 1
        }
        if camToDelete != nil{
            cameras.remove(at: camIndex)
        }
        lock.unlock()
        return discoCamera
        
    }
    
    func populateCamera(camera: Camera){
        let ipa = camera.getBaseFileName()
        let capsPath = FileHelper.getPathForFilename(name: ipa + "_capabilities.xml")
        let dInfoPath = FileHelper.getPathForFilename(name: ipa + "_device_info.xml")
        let netIfPath = FileHelper.getPathForFilename(name: ipa + "_GetNetworkInterfaces.xml")
        let profilesPath = FileHelper.getPathForFilename(name: ipa + "_get_profiles.xml")
        
        
        do {
            
            if FileManager.default.fileExists(atPath: capsPath.path) {
               
                let xml = try String(contentsOf: capsPath)
                let data = xml.data(using: .utf8)
                
                let faultParser = FaultParser()
                faultParser.parseRespose(xml: data!)
                
                if faultParser.hasFault(){
                    print("AllCameras: CAPABILITIES FAULT")
                    print(faultParser.authFault,faultParser.faultReason)
                    
                }else{
                    CameraUpdater.updateCapabilties(camera: camera, data: data)
                   
                }
            }
            if FileManager.default.fileExists(atPath: dInfoPath.path) {
               
                let xml = try String(contentsOf: dInfoPath)
                let data = xml.data(using: .utf8)
                
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    camera.authenticated = false
                    camera.authFault = parser.authFault.trimmingCharacters(in: CharacterSet.whitespaces)
                    //self.saveSoapPacket(method: camera.name+"_device_info_err", xml: soapPacket)
                    
                }else{
                    
                    CameraUpdater.updateDeviceInfo(camera: camera, data:data)
                }
            }
            if FileManager.default.fileExists(atPath: netIfPath.path){
                let xml = try String(contentsOf: netIfPath)
                if let data = xml.data(using: .utf8){
                    CameraUpdater.updateNetworkInterfaces(camera: camera, data: data)
                }
            }
            if FileManager.default.fileExists(atPath: profilesPath.path) {
               
                let xml = try String(contentsOf: profilesPath)
                let data = xml.data(using: .utf8)
                
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    camera.authenticated = false
                    camera.authFault = parser.authFault.trimmingCharacters(in: CharacterSet.whitespaces)
                    //self.saveSoapPacket(method: camera.name+"_device_info_err", xml: soapPacket)
                    
                }else{
                    let profileParser = ProfileXmlParser()
                    profileParser.parseRespose(xml: data!)
                    
                    camera.profiles = profileParser.profiles
                    camera.profileIndex = 0
                    camera.authenticated = true
                }
            }
        
            try populateProfiles(camera: camera)
            
            print("AllCameras:addCamera",camera.name,camera.xAddr)
        }
        catch{
            print("AllCameras:addCamera: \(error)")
        }
    }
    func populateProfiles(camera: Camera) throws {
        if camera.profiles.count == 0 {
            return
        }
        let ipa = camera.getBaseFileName()
        for i in 0...camera.profiles.count-1 {
            let cp = camera.profiles[i]
            let profilePath = FileHelper.getPathForFilename(name: ipa + "_get_profile_"+String(i)+".xml")
            if FileManager.default.fileExists(atPath: profilePath.path) {
               
                let xml = try String(contentsOf: profilePath)
                let data = xml.data(using: .utf8)
                
                let videoSrcParser = ProfileVideoSourceParser()
                videoSrcParser.parseRespose(xml: data!)
                
                cp.videoSrcToken = videoSrcParser.token
                cp.videoSourceId = videoSrcParser.getVideoSourceId()
                
                let zoomSpeedParser = PtzZoomProfileXmlParser()
                zoomSpeedParser.parseRespose(xml: data!)
                if zoomSpeedParser.hasPtzSpeeds || zoomSpeedParser.hasPtzConfig{
                    cp.zoomRange = [zoomSpeedParser.zoomSpeed,zoomSpeedParser.zoomSpeed]
                }
                
                let ptzParser = PtzProfileXmlParser()
                ptzParser.parseRespose(xml: data!)
                
                if(ptzParser.hasPtzSpeeds || ptzParser.hasPtzConfig){
                    cp.ptzSpeeds = [ptzParser.ptzXSpeed,ptzParser.ptzYSpeed,zoomSpeedParser.zoomSpeed]
                }
                
                try populateStreamUrl(ipa: ipa,camera: camera,profileIndex: i)
            }
        }
    }
    func populateStreamUrl(ipa: String,camera: Camera,profileIndex: Int) throws {
        let profilePath = FileHelper.getPathForFilename(name: ipa + "_get_stream_uri"+String(profileIndex)+".xml")
        if FileManager.default.fileExists(atPath: profilePath.path) {
            let xml = try String(contentsOf: profilePath)
            let data = xml.data(using: .utf8)
           
            let parser = SingleTagParser(tagToFind: "tt:Uri")
            parser.parseRespose(xml: data!)
            
            if parser.tagFound {
                let xmlIpa = URL(string: parser.result)!.host!
                //note NOT URL here in AllCameras, it is the IP address only
                let serviceIpa =  URL(string: camera.xAddr)!.host!
                
                if(xmlIpa != serviceIpa){
                    //print("XAddrParser updating IP",xmlIpa,serviceIpa)
                    let xAddr = parser.result.replacingOccurrences(of: xmlIpa, with: serviceIpa)
                    camera.profiles[profileIndex].url = xAddr
                }else{
                    camera.profiles[profileIndex].url = parser.result
                }
            }
       
        }
    }
}
