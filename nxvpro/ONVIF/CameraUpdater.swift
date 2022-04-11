//
//  CameraUpdater.swift
//  NX-V
//
//  Created by Philip Bishop on 30/12/2021.
//
import Foundation

class CameraUpdater{
    static func updateCameraUri(camera: Camera,uri: String) -> String{
        if let camUri = URL(string: camera.xAddr){
            if let otherUri = URL(string: uri){
                if let chost = camUri.host{
                    if let ohost = otherUri.host{
                        if chost != ohost{
                            return uri.replacingOccurrences(of: ohost, with: chost)
                        }
                    }
                }
            }
        }
        return uri
    }
    static func updateDeviceInfo(camera: Camera,data: Data?){
        let xmlParser = XmlPathsParser(tag: ":GetDeviceInformationResponse")
        xmlParser.parseRespose(xml: data!)
        let xpaths = xmlParser.itemPaths
        
        camera.deviceInfo = [String:String]()
        #if DEBUG
        if camera.xAddr.contains("8086"){
            print("Debug",xpaths)
        }
        #endif
        for xpath in xpaths{
            let kvp = xmlParser.getKeyValuePair(xpath: xpath)
            if kvp.count == 2 {
                camera.deviceInfo![kvp[0]]=kvp[1]
                
                if kvp[0] == "Model"{
                    camera.makeModel = kvp[1].htmlDecoded
                }
            }
        }
        
        if camera.name.isEmpty || camera.name == Camera.DEFUALT_NEW_CAM_NAME{
            camera.name = camera.makeModel.htmlDecoded
        }else if camera.name.htmlDecoded.contains(camera.makeModel.htmlDecoded) == false{
            camera.name = camera.name + " " + camera.makeModel
        }
    }
    static func updateCapabilties(camera: Camera,data: Data?){
        
        var parser = XAddrParser(tagToFind: "Media",serviceXAddr: camera.xAddr)
        parser.parseRespose(xml: data!)
        
        camera.mediaXAddr = parser.xAddr
        
        parser = XAddrParser(tagToFind: "PTZ",serviceXAddr: camera.xAddr)
        parser.parseRespose(xml: data!)
        
        camera.ptzXAddr = parser.xAddr
        
        parser = XAddrParser(tagToFind: "Imaging",serviceXAddr: camera.xAddr)
        parser.parseRespose(xml: data!)
        camera.imagingXAddr = parser.xAddr
        
        print("camera XAddrs",camera.mediaXAddr,camera.ptzXAddr,camera.imagingXAddr)
       
        if Camera.IS_NXV_PRO{
            parser = XAddrParser(tagToFind: "Recording",serviceXAddr: camera.xAddr)
            parser.parseRespose(xml: data!)
            
            camera.recordingXAddr = parser.xAddr
            
            parser = XAddrParser(tagToFind: "Replay",serviceXAddr: camera.xAddr)
            parser.parseRespose(xml: data!)
            
            camera.replayXAddr = parser.xAddr
            
            parser = XAddrParser(tagToFind: "Search",serviceXAddr: camera.xAddr);
            parser.parseRespose(xml: data!);
            camera.searchXAddr = parser.xAddr;
            
            print("camera XAddres",camera.mediaXAddr,camera.ptzXAddr,camera.recordingXAddr,camera.replayXAddr,camera.searchXAddr)
            
            let xmlParser = XmlPathsParser(tag: "System")
            xmlParser.parseRespose(xml: data!)
            let xpaths = xmlParser.itemPaths
            var supportedVersion = ""
            
            for xpath in xpaths{
                let path = xpath.components(separatedBy: "/")
                let np = path.count
                let key = path[0].components(separatedBy: ":")
                guard key.count > 1 else{
                    continue
                }
                if key[1] == "SupportedVersions" && np>=2{
                    let vkey = path[np-2].components(separatedBy: ":")
                    guard vkey.count > 1 else{
                        continue
                    }
                    if vkey[1] == "Major"{
                        supportedVersion.append(path[np-1])
                        supportedVersion.append(".")
                        //print("major",path[np-1])
                    }else if vkey[1] == "Minor"{
                        //print("minor",path[np-1])
                        supportedVersion.append(path[np-1])
                        supportedVersion.append(" ")
                        
                    }
                }else if key[1] == "SystemLogging"{
                    if path[np-1] == "true"{
                        camera.systemLogging = true
                    }
                }else if key[1] == "SystemBackup"{
                    if path[np-1] == "true"{
                        camera.systemBackup = true
                    }
                }
            }
            
            if supportedVersion.isEmpty == false{
                camera.supportedOnvifVers = supportedVersion
            }
        }
    }

    static func updateNetworkInterfaces(camera: Camera,data: Data?){
        
        camera.networkInfo = [String:String]()
        
        let xmlParser = XmlPathsParser(tag: ":GetNetworkInterfacesResponse")
        xmlParser.parseRespose(xml: data!)
        let xpaths = xmlParser.itemPaths
        
        for xpath in xpaths{
            let path = xpath.components(separatedBy: "/")
            let np = path.count
            if np > 2 {
                let key = path[np-2].components(separatedBy: ":")
                guard key.count > 1 else{
                    continue
                }
                if key[1] == "HwAddress"{
                    camera.networkInfo!["Mac address"] = path[np-1]
                }
            }
        }
    }
    static func handleGetUsers(camera: Camera,xpaths: [String],data: Data?){
        
        camera.systemUsers.removeAll()
        var currentUser: CameraUser?
        var nextId = 0
        for xpath in xpaths{
            let parts = xpath.components(separatedBy: "/")
            let np = parts.count
            let key = parts[1].components(separatedBy: ":")
            guard key.count > 1 else{
                continue
            }
            if key[1] == "Username"{
                currentUser = CameraUser(id: nextId,name: parts[np-1])
                nextId += 1
            }else if key[1] == "UserLevel"{
                currentUser!.role = parts[np-1]
                
                camera.systemUsers.append(currentUser!)
            }
        }
        
        print("cameraUpdater:handleGetUsers",camera.systemUsers.count)
    }
    static func handleGetStorageConfigurations(camera: Camera,xpaths: [String],data: Data?){
        print("CameraUpdater:handleGetStorageConfigurations",xpaths)
    }
}
