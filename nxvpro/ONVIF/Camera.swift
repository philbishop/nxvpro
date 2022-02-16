//
//  Camera.swift
//  NX-V
//
//  Created by Philip Bishop on 23/05/2021.
//

import Foundation

protocol CameraChanged {
    func onCameraChanged()
    func getSrc() -> String
}
class CameraUser : Hashable{
    static func == (lhs: CameraUser, rhs: CameraUser) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    
    var id = 0
    var name: String
    var pwd: String
    var role: String
    
    init(id: Int,name: String,pwd: String = "",role: String = ""){
        self.id = id
        self.name = name
        self.pwd = pwd;
        self.role = role
    }
}
class CameraProfile{
    var token: String
    var name: String
    var videoSourceId = ""
    var videoSrcToken = ""
    var encoderConfigToken = ""
    var videoEncoderConfToken = ""
    var resolution: String
    var url: String
    var snapshotUrl: String
    var ptzSpeeds = ["","",""]
    var zoomRange = ["",""]
    
    init(name: String, resolution: String,url: String,snapshotUrl: String){
        self.name = name
        self.resolution = resolution
        self.url = url
        self.snapshotUrl = snapshotUrl
        self.token = ""
    }
    func getDisplayResolution(useToken: Bool) -> String{
        return useToken ? token : resolution
    }
    func isSameProfile(selectedRs: String) -> Bool{
        return resolution == selectedRs || token == selectedRs
    }
    func getResolution() -> [Double]{
        var res = [Double]()
        //split resolution then parse parts
        let wh = resolution.components(separatedBy: "x")
        if wh.count == 2 {
            res.append((wh[0] as NSString).doubleValue)
            res.append((wh[1] as NSString).doubleValue)
            
        }
        return res
    }
    
    func getDisplayName(useResolution: Bool) -> String{
        return useResolution ? resolution : name
    }
}
class CameraLocation : Codable {
    var camUid = ""
    var lat = Double(0)
    var lng = Double(0)
    var beam = 0.0
    var xtra = [String]()
    
    var angle: Double{
        get{
            return beam
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case camUid = "Uid"
        case lat = "Lat"
        case lng = "Lng"
        case beam = "Beam"
        case xtra = "Xtra"
    }
    
}
class PtzPreset : Hashable{
    static func == (lhs: PtzPreset, rhs: PtzPreset) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(token)
    }
    var id: Int
    var token: String
    var name: String
    
    init(id: Int,token: String,name: String){
        self.id = id
        self.token = token
        self.name = name
    }
}

class CameraSettings : Codable {
    
    var name: String = ""
    var displayName: String = ""
    var user: String = ""
    var password: String = ""
    var rotationAngle: Int = 0
    var isFavorite: Bool = false
    var vmdOn: Bool = false
    var vmdSens: Int = 0
    var vmdVidOn: Bool = false
    var vmdRecTime: Int = 10
    var muted: Bool = false
    var profileIndex: Int = -1
    var displayOrder: Int?
    var isVisible: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case displayName = "DisplayName"
        case user = "User"
        case password = "Password"
        case rotationAngle = "RotationAngle"
        case isFavorite = "IsFavorite"
        case vmdOn = "VmdOn"
        case vmdSens = "VmdSens"
        case vmdVidOn = "VmdVidOn"
        case vmdRecTime = "VmdRecTime"
        case muted = "Muted"
        case profileIndex = "ProfileIndex"
        case displayOrder = "DisplayOrder"
        case isVisible = "IsVisible"
    }
   
}

class Camera : ObservableObject, Hashable{
    
    static var IS_NXV_PRO = true
    static var IMAGING_ENABLED = false
    static var VCAM_BASE_ID: Int = 1000
    static var MIN_NAME_LEN = 3
    static var MAX_NAME_LEN = 12
    static var DEFUALT_NEW_CAM_NAME = "+IP-CAM"
    var isVirtual: Bool = false
    var vcamId: Int = -1
    
    var id: Int
    var name: String = ""
    var displayName: String = ""
    var displayOrder: Int = -1
    var makeModel: String = ""
    var user: String = "" {
        didSet{
            print("Camera:user",name,user)
        }
    }
    var password: String = ""
    var xAddr: String = ""
    var ptzXAddr: String = ""
    var mediaXAddr: String = ""
    var imagingXAddr = ""
    var recordingXAddr = ""
    var replayXAddr = ""
    var searchXAddr = ""
    var supportedOnvifVers = ""
    
    var authenticated: Bool = false
    var authFault: String = ""
    var connectTime: Date =  Date()
    var profileIndex: Int = -1
    
    var profiles = [CameraProfile]()
    var listener: CameraChanged?
    
    var location: [Double]?
    var locationAddress = ""
    
    func hasValidLocation() -> Bool{
        if let loc = location{
            return loc[0] != 0.0
        }
        
        return false
    }
    
    var beamAngle = 0.0
    //transient
    var hasRecentAlerts = false
    
    var storageSettings = StorageSettings()
    
    var rotationAngle: Int = 0 {
        didSet{
            //check added 6.1.5
            if oldValue != rotationAngle{
                save()
            }
        }
    }
    var isFavorite: Bool = false {
        didSet{
            if oldValue != isFavorite {
                flagChanged()
            }
        }
    }
    var vmdOn: Bool = false{
        didSet{
            print("vmdOn",vmdOn,getDisplayAddr())
        }
    }
    var vmdSens: Int = 0
    var vmdVidOn: Bool = true //iOS always on
    var vmdRecTime: Int = 10
    var muted: Bool = false
    
    //transient
    var videoProfiles = [VideoProfile]()
    var deviceInfo: [String:String]?
    var networkInfo: [String:String]?
    
    var systemLogging = false
    var systemBackup = false
    
    var systemUsers = [CameraUser]()
    
    var recordingProfile: RecordProfileToken?
    
    var ptzPresets: [PtzPreset]?
    var orderListener: CameraChanged?
    var xAddrId: String{
        if isVirtual{
            return xAddr + "/" + String(vcamId)
        }
        return xAddr
    }
    var timeCheckOk: Bool = false // used for unicast check on not discovered
    var isZombie: Bool = false
    var wsaAddr: String = ""
    
    var imagingOpts: [ImagingType]?
    var imagingFault = ""
   
    
    init(id: Int)
    {
        self.id = id
    }
   
    func matchesFilter(filter: String) -> Bool{
        if filter.isEmpty{
            return true
        }
        let dnl = getDisplayName().lowercased()
        return dnl.contains(filter.lowercased())
    }
    func getDisplayName() -> String {
        var cname = name
        if cname == Camera.DEFUALT_NEW_CAM_NAME && makeModel.isEmpty == false{
            cname = makeModel.htmlDecoded
        }
        if displayName == Camera.DEFUALT_NEW_CAM_NAME && makeModel.isEmpty == false{
            displayName = makeModel.htmlDecoded
        }
        if displayName.isEmpty{
            if name.isEmpty && makeModel.isEmpty==false{
                cname = makeModel.htmlDecoded
            }
            if cname.count > Camera.MAX_NAME_LEN {
                return Helpers.truncateString(inStr: cname, length: Camera.MAX_NAME_LEN).htmlDecoded
            }
            return name
        }
        
        if displayName.isEmpty{
            return name
        }
        
        if displayName.count > Camera.MAX_NAME_LEN {
            return Helpers.truncateString(inStr: displayName, length: Camera.MAX_NAME_LEN).htmlDecoded
        }
        return displayName.htmlDecoded
    }
    func getProperties(includeProfiles: Bool = false) -> [(String,String)] {
            var props = [(String,String)]()
        
            //name is not included
            
            //props.append(("Make/Model",makeModel.htmlDecoded))
            if let dInfo = deviceInfo{
                for (key,value) in dInfo{
                    props.append((key,value))
                }
            }else{
                props.append(("Make/Model",makeModel.htmlDecoded))
            }
            
            if Camera.IS_NXV_PRO{
            
                if let netInfo = networkInfo {
                    for (key,value) in netInfo{
                        props.append((key,value))
                    }
                }
                props.append(("System logging",(systemLogging ? "Yes" : "No")))
                props.append(("System backup",(systemBackup ? "Yes" : "No")))
            }
            if supportedOnvifVers.isEmpty == false{
                props.append(("ONVIF versions",supportedOnvifVers))
            }
            
            props.append(("Device endpoint",xAddr))
            props.append(("Media endpoint",mediaXAddr))
            
            if Camera.IS_NXV_PRO{
                if !imagingXAddr.isEmpty{
                    props.append(("Imaging endpoint",imagingXAddr))
                }
                if !searchXAddr.isEmpty{
                    props.append(("Search endpoint",searchXAddr))
                }
            }
            
            if hasPtz(){
                props.append(("PTZ endpoint",ptzXAddr))
            }
        
    
        return props
    }
    
    func hasPtz() -> Bool {
        if profiles.count == 0 || profileIndex < 0{
            return false
        }
        return ptzXAddr.isEmpty == false &&
            profiles[profileIndex].ptzSpeeds[0].isEmpty == false
    }
    func hasImaging() -> Bool{
        if imagingXAddr.isEmpty || imagingOpts == nil{
            return false
        }
        if let iops = imagingOpts{
            return iops.count > 2
        }
        return false
        
    }
    func getAspectRatio() -> Double{
        if let profile = selectedProfile(){
            let cres = profile.getResolution()
            return cres[0] / cres[1]
        }
        //default
        return 1920.0 / 1080.0
        
    }
    func selectBestProfile(){
        if profiles.count > 0 {
            if profiles[0].getResolution()[0]<=1920.0 {
                profileIndex = 0
            }else {
                if profiles.count > 1 {
                    profileIndex = 1
                }
            }
            print("Camera:selectBestProfile",name,selectedProfile()?.resolution)
            save()
        }
        
    }
    func setSelectedProfile(res: String){
        if profiles.count > 0 {
            for i in 0...profiles.count-1 {
                if(profiles[i].resolution == res){
                    profileIndex = i;
                    print("Camera:setSelectedProfile",profiles[i].resolution)
                    break;
                }
            }
        }
    }
    func getDisplayResolution() -> String{
        let sp = selectedProfile()
        if sp != nil {
            return sp!.resolution
        }
        return "N/A"
    }
    func hasStreamingUti() -> Bool{
        let sp = selectedProfile()
        if sp != nil && sp?.url != nil{
            return true
        }
        return false
    }
    func selectedProfile() -> CameraProfile?{
        
        if profileIndex == -1 && profiles.count > 0 {
           selectBestProfile()
        }
        if profileIndex != -1 && profileIndex < profiles.count  {
           
           return profiles[profileIndex]
           
        }
        
        print("Camera:selectedProfile, returning nil",profileIndex,profiles.count)
        return nil
    }
    
    func setListener(listener: CameraChanged){
        self.listener = listener
    }
    func flagChanged(){
        print("Camera;flagChanged",name,isAuthenticated(),profiles.count)
        self.listener?.onCameraChanged()
    }
    func getDisplayAddr() -> String {
    
        if xAddr.hasPrefix("http") == false {
            return xAddr
        }
        
        let nsurl = NSURL(string: xAddr)!
        let addr = nsurl.host!
        return addr
    }
    
    func getInfo() -> String {
        if profiles.count == 0 {
            return "Not authentiated"
        }
        return profiles[0].resolution
    }
    
    func isAuthenticated() -> Bool {
        return profiles.count > 0 && authenticated && user.isEmpty == false
    }
    //One of Andy's cameras has not proper auth so need to check if URI exists
    func hasProfileUri() -> Bool{
        return profiles.count > 0 && profiles[0].url.isEmpty == false
    }
    func save(){
      
        var cset = CameraSettings()
        cset.name = name
        cset.displayName = displayName
        cset.user = user
        cset.password = password
        cset.isFavorite = isFavorite
        cset.vmdOn = vmdOn
        cset.vmdSens = vmdSens
        cset.rotationAngle = rotationAngle
        cset.vmdVidOn = vmdVidOn
        cset.vmdRecTime = vmdRecTime
        cset.muted = muted
        cset.profileIndex = profileIndex
        cset.displayOrder = displayOrder
        cset.isVisible = vcamVisible
        
        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(cset) {
            let jfn = getJFileName()
            
            AppLog.write("Camera:save",jfn)
                
            
            let jpc = FileHelper.getPathForFilename(name: jfn)
            do {
                try encodedData.write(to: jpc)
            }
            catch {
                print("Failed to write JSON data: \(error.localizedDescription)")
            }
            
        }
  
    }
    
    var isLoading = false
    func loadCredentials() -> Bool{
        isLoading = true
        let ok = loadCredentialsImpl()
        isLoading = false
        
        return ok
        
    }
    func loadCredentialsImpl() -> Bool{
        if xAddr.isEmpty{
            return false
        }
        let jfn = getJFileName()
        let filePath = FileHelper.getPathForFilename(name: jfn)
        
        print("Camera:loadCredentials",filePath.path)
        
        if FileManager.default.fileExists(atPath: filePath.path) {
            do {
                let jsonData = try Data(contentsOf: filePath)
                let cset = try JSONDecoder().decode(CameraSettings.self, from: jsonData)
            
                name = cset.name
                displayName = cset.displayName
                if displayName.isEmpty {
                    displayName = name
                }
                user = cset.user
                password = cset.password
                isFavorite = cset.isFavorite
                rotationAngle = cset.rotationAngle
                vmdOn = cset.vmdOn
                vmdSens = cset.vmdSens
                vmdVidOn = cset.vmdVidOn
                vmdRecTime = cset.vmdRecTime
                muted = cset.muted
                profileIndex = cset.profileIndex
                
                if cset.displayOrder != nil {
                    displayOrder = cset.displayOrder!
                }
                if cset.isVisible != nil{
                    vcamVisible = cset.isVisible!
                }
                
                print("JSON deser",user,password,id)
                return true
                
            } catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                print("FAILED TO LOAD JSON",filePath.path)
            }
            
        }
        return false
    }
  
    func getStringUid() -> String{
        let bid = getBaseFileName()
        if isVirtual{
            return bid + "_" + String(vcamId)
        }
        return bid
    }
    //MARK: File naming conventions
    func getJFileName() -> String {
        var fn = getBaseFileName()
        if id>=Camera.VCAM_BASE_ID{
            fn = fn + "_" + String(vcamId)
        }
        return fn + ".json"
    }
    func getBaseFileName() -> String {
        if xAddr.hasPrefix("http"){
            let url = NSURL(string: xAddr)!
            var port = "80";
            if url.port != nil{
                port = url.port!.stringValue
            }
            let fn = url.host! + "_" + port
            return fn
        }
        return xAddr;
    }
    func thumbPath() -> String {
        let noThumb = Bundle.main.path(forResource: "nxv_icon_gray_thumb",ofType: "png")!
        if name.isEmpty {
            return noThumb
        }
        let tpath = FileHelper.getPathForFilename(name: thumbName())
        if FileManager.default.fileExists(atPath:  tpath.path){
            return tpath.path
        }else{
            return noThumb
        }
    }
    func thumbName() -> String{
        /*
        var host = xAddr
        if xAddr.hasPrefix("http") {
            let url = URL(string: xAddr)!
            host = url.host!
        }
        return host + "_" + name+".jpg".replacingOccurrences(of: " ", with: "_")
         */
        if isVirtual{
            return getBaseFileName() + "_" + name + ".jpg"
        }
        return getBaseFileName() + ".jpg"
    }
    
    //MARK: Hashable
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(xAddr)
        
        }
    
    static func == (lhs: Camera, rhs: Camera) -> Bool {
        return rhs.id == lhs.id && rhs.xAddr == lhs.xAddr
    }
    /*
    //MARK: Update from newly discovered camera matching wasAdd
    func updateCamera(other: Camera){
        let oldAddr = URL(string: xAddr)!
        let newAddr = URL(string: other.xAddr)!
        
        xAddr = other.xAddr
        mediaXAddr = other.mediaXAddr
        ptzXAddr = other.ptzXAddr
        mediaXAddr = other.mediaXAddr
        //searchXAddr = other.searchXAddr
        //replayXAddr = other.replayXAddr
        //recordingXAddr = other.recordingXAddr
     
        for pf in profiles{
            pf.url = pf.url.replacingOccurrences(of: oldAddr.host!, with: newAddr.host!)
        }
        
        flagChanged()
    }
     */
    func hasDuplicateResolutions() -> Bool{
        var resolutions = [String]()
        for cp in profiles {
            if resolutions.contains(cp.resolution){
                return true
            }
            resolutions.append((cp.resolution))
        }
        return false
    }
    func getProfileProperties()->[(String,String)]{
        var props = [(String,String)]()
        if profiles.count > 0 {
            for i in 0...profiles.count-1{
                let cp = profiles[i]
                props.append((cp.token,""))
                props.append(("Name",cp.name))
                props.append(("Resolution",cp.resolution))
                props.append(("Uri",cp.url))
                if hasPtz(){
                    props.append(("PTZ",(cp.ptzSpeeds[0].isEmpty ? "No" : "Yes")))
                }
            }
        }
        return props

    }
    //MARK: NVR experimental code
    var _isNvr: Bool?
    func isExistingNvr() -> Bool{
        //check if we have a _1.json
        var jfn = getJFileName()
        let vcamfn = jfn.replacingOccurrences(of: ".json", with: "_1.json")
        let vfnPath = FileHelper.getStorageRoot().appendingPathComponent(vcamfn)
        return FileManager.default.fileExists(atPath: vfnPath.path)
        
    }
    func isNvr() -> Bool{
        if isVirtual || Camera.IS_NXV_PRO == false{
            return false
        }
        if let nvr = _isNvr{
            if nvr && vcams.count == 0{
                getVirtualCameras()
            }
            return _isNvr!
        }
        
        /*
        let hasEvenProfiles = profiles.count > 0 && (profiles.count % 2) == 0
        if !hasEvenProfiles  || profiles.count < 4{
            return false
        }
        var resolutions = [String]()
        for cp in profiles {
            if resolutions.contains(cp.resolution){
                getVirtualCameras()
                _isNvr = true
                return true
            }
            resolutions.append((cp.resolution))
        }
        
        _isNvr = false
         */
        
        let nvcams = getVirtualCameras()
        
        if nvcams > 1{
            _isNvr = true
            return true
        }
        return false;
        
    }
    var vcams = [Camera]()
    var vcamVisible = true;
    let vlock = NSLock()
    
    func getVCams() -> [Camera]{
        getVirtualCameras()
        return vcams
    }
    func getVirtualCameras() -> Int {
        
        if vcams.count > 0 {
            print("Camera:getVirtualCameras, already loaded",vcams.count)
            return vcams.count
        }
        
        vcams = [Camera]()
        if vcamVisible == false  || profiles.count < 2{
            return vcams.count
        }
        
        var videoSourceList = [String]()
        var videoSources = [String:[Int]]()
        for i in 0...profiles.count-1{
            let cp = profiles[i]
            if videoSources[cp.videoSourceId] == nil{
                videoSources[cp.videoSourceId] = [Int]()
                videoSourceList.append(cp.videoSourceId)
            }
            videoSources[cp.videoSourceId]!.append(i)
        }
        if videoSources.count < 2 || videoSources.count == profiles.count{
            return 0
        }
        var vcamId = 1;
        var baseVcamName = getDisplayName()
        let vclen = Camera.MAX_NAME_LEN - 4
        if baseVcamName.count > vclen {
            baseVcamName = Helpers.truncateString(inStr: baseVcamName,length: vclen)
        }
        var cid = id + Camera.VCAM_BASE_ID
        if cid < Camera.VCAM_BASE_ID{
            cid = Camera.VCAM_BASE_ID
        }
        for videoSrc in videoSourceList{
            let pids = videoSources[videoSrc]!
            let vcam = Camera(id: cid)
            //vcamId used for getJFilename
            vcam.vcamId = vcamId
            vcam.isVirtual = true
            vcam.user = user
            vcam.password = password
            vcam.authenticated = true
            //let mainProfile = profiles[pids[0]]
            vcam.name =  "P" + String(vcamId) + " " + baseVcamName //mainProfile.name
            vcam.displayName = vcam.name
            vcam.makeModel = makeModel
            vcam.xAddr = xAddr
            vcam.ptzXAddr = ptzXAddr
            vcam.mediaXAddr = mediaXAddr
            vcam.imagingXAddr = imagingXAddr
            //vcam.searchXAddr = searchXAddr
            //vcam.replayXAddr = replayXAddr
            //vcam.recordingXAddr = recordingXAddr
            vcam.profileIndex = 0
            vcam.profiles = [CameraProfile]()
            for pid in pids{
                vcam.profiles.append(profiles[pid])
            }
            vcam.displayOrder = cid + vcamId
            let exists = vcam.loadCredentials()
            if !exists {
                vcam.save()
            }
           
            vcams.append(vcam)
            vcamId += 1
            cid += 1
        }
        AppLog.dumpCamera(camera: self)
        return vcams.count
    }
    //MARK: Storage settings
    func getJStorageFileName(storageType: String) -> String {
            var fn = getBaseFileName()
            if id>=Camera.VCAM_BASE_ID{
                fn = fn + "_" + String(vcamId)
            }
            return fn + "_" + storageType + ".json"
        }
    func saveStorageSettings(storageType: String){
        let jfn = getJStorageFileName(storageType: storageType)
        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(storageSettings){
            let jpc = FileHelper.getPathForFilename(name: jfn)
            do {
                try encodedData.write(to: jpc)
            }
            catch {
                print("Failed to write storage JSON data: \(error.localizedDescription)")
            }
        }
    }
    func loadStorageSettings(storageType: String){
        let jfn = getJStorageFileName(storageType: storageType)
        let jpc = FileHelper.getPathForFilename(name: jfn)
        if FileManager.default.fileExists(atPath: jpc.path){
            do {
                let jsonData = try Data(contentsOf: jpc)
                let sset = try JSONDecoder().decode(StorageSettings.self, from: jsonData)
                storageSettings = sset
                
            }catch{
                print("Failed to read storage JSON data: \(error.localizedDescription)")
            }
        }
    }
    //MARK: Location storage
    func getJLocationFileName() -> String {
            var fn = getBaseFileName()
            if id>=Camera.VCAM_BASE_ID{
                fn = fn + "_" + String(vcamId)
            }
            return fn + "_loc.json"
        }
    func saveLocation(){
        let camLoc = CameraLocation()
        camLoc.camUid = getStringUid()
        
        if let loc = location{
            camLoc.lat = loc[0]
            camLoc.lng = loc[1]
        }
        camLoc.beam = beamAngle
        
        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(camLoc) {
            let jfn = getJLocationFileName()
            let jpc = FileHelper.getPathForFilename(name: jfn)
            do {
                try encodedData.write(to: jpc)
            }
            catch {
                print("Failed to write Location JSON data: \(error.localizedDescription)")
            }
            
        }
    }
    var locationLoaded = false
    func loadLocation(){
        let jfn = getJLocationFileName()
        let jpc = FileHelper.getPathForFilename(name: jfn)
        if FileManager.default.fileExists(atPath: jpc.path){
            print("Camera:loadLocation",jfn)
            location = nil
            do {
                let jsonData = try Data(contentsOf: jpc)
                let cloc = try JSONDecoder().decode(CameraLocation.self, from: jsonData)
                
                if cloc.lat != 0{
                    location = [cloc.lat,cloc.lng]
                }
                beamAngle = cloc.angle
                locationLoaded = true
            }
            catch {
                print("Failed to load location JSON data: \(error.localizedDescription)")
            }
        }
    }
}
