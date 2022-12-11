//
//  CameraGroup.swift
//  NX-V
//
//  Created by Philip Bishop on 09/09/2021.
//

import Foundation

protocol GroupChangedListener{
    func moveCameraToGroup(camera: Camera,grpName: String) -> [String]
}

class CameraGroups : ObservableObject{
    @Published var groups: [CameraGroup]
    
    var flatGroups = [String]()
    
    init(){
        groups = [CameraGroup]()
        loadFromJson()
    }
    func reset(){
        groups.removeAll()
        loadFromJson()
    }
    func cameraAdded(camera: Camera){
        
        for grp in groups{
            grp.addCameraIfInGroup(camera: camera)
        }
    }
    func hasUnassignedCameras(allCameras: [Camera]) -> Bool{
        for cam in allCameras{
            if cam.isNvr(){
                continue
            }
            if isCameraInGroup(camera: cam) == false{
                return true
            }
        }
        return false
    }
    func isCameraInGroup(camera: Camera) -> Bool {
        for cg in groups{
            for ipa in cg.cameraIps{
                if ipa == camera.getBaseFileName(){
                    return true
                }
            }
        }
        
        return false
    }
    func isCamGroupHidden(camera: Camera) ->Bool{
        for cg in groups{
            for ipa in cg.cameraIps{
                if ipa == camera.getBaseFileName(){
                    if let camsVisible = cg.camsVisible{
                        return !camsVisible
                    }
                    return false
                }
            }
        }
        return false
    }
    func getNames() -> [String]{
        var names = [String]()
        for cg in groups{
            names.append(cg.name)
        }
        return names;
    }
    func getGroupFor(camera: Camera) -> CameraGroup?{
        for cg in groups{
            for ipa in cg.cameraIps{
                if ipa == camera.getBaseFileName(){
                    return cg
                }
            }
        }
        
        return nil
    }
    func getGroupNameFor(camera: Camera) -> String{
        for cg in groups{
            
            for ipa in cg.cameraIps{
                if ipa == camera.getBaseFileName(){
                    return cg.name
                }
            }
        }
        
        return CameraGroup.DEFAULT_GROUP_NAME
    }
    func updateGroups(oldIP: String,newIp: String){
        for grp in groups{
            grp.updateAddress(oldIp: oldIP, newIp: newIp)
        }
    }
    func loadFromJson(){
        
        groups.removeAll()
        flatGroups.removeAll()
        
        var miscGrp: CameraGroup?
        let fileTag = "_grp.json"
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
                let filePath = FileHelper.getPathForFilename(name: file)
                let jsonData = try Data(contentsOf: filePath)
                let group = try JSONDecoder().decode(CameraGroup.self, from: jsonData)
                if group.cameraIps.count > 0 {
                    if group.name == CameraGroup.MISC_GROUP{
                        miscGrp = group
                    }else{
                        groups.append(group)
                    }
                    if let jsonStr = String(data: jsonData,encoding: .utf8){
                        flatGroups.append(jsonStr)
                    }
                }else{
                    try FileManager.default.removeItem(at: filePath)
                }
            }
            
            if miscGrp != nil{
                groups.append(miscGrp!)
            }
            
            
        }
        catch{
            print("CameraGroups:loadFromJson: \(error)")
        }
    }
    func populateCameras(cameras: [Camera]){
        //flush existing
        for cg in groups{
            cg.cameras.removeAll()
        }
        for cam in cameras{
            let ipa = cam.getBaseFileName()
            for cg in groups{
                for ip in cg.cameraIps{
                    if ip == ipa{
                        cg.cameras.append(cam)
                        break;
                    }
                }
            }
        }
    }
    func removeFromExistingGroup(camera: Camera){
        let ipa = camera.getBaseFileName()
        for cg in groups{
            for ip in cg.cameraIps{
                if ip == ipa{
                    cg.remove(camera: camera)
                    cg.save()
                    AppLog.write("CameraGroup:removeForExistingGroup",ipa)
                    return;
                }
            }
        }
    }
    func addCameraToGroup(camera: Camera,grpName: String){
        removeFromExistingGroup(camera: camera)
        
        if grpName == CameraGroup.DEFAULT_GROUP_NAME{
            return
        }
        
        for cg in groups{
           
            if cg.name == grpName{
               
               cg.addCameraIfNotExists(camera: camera)
                cg.save()
                //saveGrp(cg: cg)
                return
            }
        }
        createNewGroup(camera: camera,grpName: grpName)
        
        loadFromJson()
        
        
    }
    
    
    private func createNewGroup(camera: Camera,grpName: String) -> CameraGroup{
        
        var maxId = 0
        for cg in groups{
            //if we have an empty group return it
            if cg.cameraIps.count == 0 {
                return cg
            }
            maxId = max(maxId,cg.id)
        }
        
        let grp = CameraGroup()
        grp.id = maxId + 1
        if grpName == CameraGroup.NEW_GROUP_NAME{
            grp.name = "Group " + String(groups.count)
        }else{
            grp.name = grpName
        }
        grp.cameraIps.append(camera.getBaseFileName())
        grp.cameras.append(camera)
       // saveGrp(cg: grp)
        grp.save()
        return grp
    }
    
}

class CameraGroup : Codable, Hashable {
    
    static var DEFAULT_GROUP_NAME = Camera.DEFAULT_TAB_NAME
    static var NEW_GROUP_NAME = "New group"
    static var MISC_GROUP = "OTHER DEVICES"
    
    var id: Int = 0
    var name: String = ""
    var cameraIps: [String] = [String]()
  
    var cameras: [Camera] = [Camera]()
    var isNvr: Bool = false
    var camsVisible: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case cameraIps = "CameraIps"
        case camsVisible = "CamsVisible"
      
    }
    func getCameras() -> [Camera]{
        var cams = [Camera]()
        for ipa in cameraIps{
            for cam in cameras{
                if cam.vcamVisible && cam.getStringUid() == ipa{
                    cams.append(cam)
                    break
                }
            }
        }
        cameras = cams
        return cams
    }
    func updateAddress(oldIp: String,newIp: String){
        if cameraIps.count == 0 {
            return
        }
        var dirty = false
        for i in 0...cameraIps.count-1{
            if cameraIps[i] == oldIp{
                cameraIps[i] = newIp
                
                print("CameraGroup:updateAddress",oldIp,newIp)
                
                dirty = true
                break
            }
        }
        if dirty{
            save()
        }
    }
    
    func save(){
        if camsVisible == nil{
            camsVisible = true
        }
        
        //update ip address from cameras
        cameraIps = [String]()
        for cam in cameras{
            cameraIps.append(cam.getStringUid())
        }
        
        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(self) {
            let jfn = String(self.id) + "_grp.json"
            let jpc = FileHelper.getPathForFilename(name: jfn)
            do {
                try encodedData.write(to: jpc)
            }
            catch {
                print("Failed to write CameraGroup JSON data: \(error.localizedDescription)")
            }
            
        }
    }
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            //hasher.combine(name)
        
        }
    static func == (lhs: CameraGroup, rhs: CameraGroup) -> Bool {
        return rhs.id == lhs.id // && rhs.name == lhs.name
    }
    
    func remove(camera: Camera){
        if cameras.count>0{
        var ci = -1
            for i in 0...cameras.count-1{
                if cameras[i].id == camera.id{
                    ci = i
                    break
                }
            }
            if ci != -1{
                cameras.remove(at: ci)
            }
        }
        var ips = [String]()
        let ipa = camera.getBaseFileName()
        for camIp in cameraIps{
            if camIp != ipa{
                ips.append(camIp)
                
            }
        }
        
        cameraIps = ips
       
        
    }
    func addCameraIfNotExists(camera: Camera){
        let ipa = camera.getBaseFileName()
        for camIp in cameraIps{
            if camIp == ipa{
                
                print("CameraGroup already contains camera",name,ipa)
                return
            }
        }
        cameraIps.append(ipa)
        cameras.append(camera)
    }
    
    func addCameraIfInGroup(camera: Camera){
        
        for camIp in cameraIps{
            if camIp == camera.getBaseFileName(){
                for cam in cameras{
                    if cam.id == camera.id{
                        return
                    }
                }
                cameras.append(camera)
            }
        }
    }
}
