//
//  OnvifDisco.swift
//  NX-VR
//
//  Created by Philip Bishop on 22/05/2021.
//

import Foundation
import CocoaAsyncSocket
import SwiftUI
import CommonCrypto
import os
import Network

extension String {
    func sha1Hash() -> String {
        let data = Data(self.utf8)
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        
        return Data(bytes: digest).base64EncodedString()
    }
    public func uint8Array() -> [UInt8] {
        var retVal : [UInt8] = []
        for thing in self.utf8 {
            retVal.append(UInt8(thing))
        }
        return retVal
    }
}

protocol DiscoveryListener {
    func cameraAdded(camera: Camera)
    func cameraChanged(camera: Camera)
    func discoveryError(error: String)
    func discoveryTimeout()
    func networkNotAvailabled(error: String)
    func zombieStateChange(camera: Camera)
}
protocol AuthenicationListener{
    func cameraAuthenticated(camera: Camera,authenticated: Bool)
}

class DiscoveredCameras : ObservableObject{
    
    let lock = NSLock()
    
    @Published var cameras = [Camera]()
    @Published var nofoundCameras = [Camera]()
    @ObservedObject var cameraGroups = CameraGroups()
    
    var recentlyDiscoveredCameras = [Camera]()
    var allCameras = AllCameras()
    var MAX_FAVS = 8
    var listener: DiscoveryListener?
    
    init(){
        allCameras.loadFromXml()
        nofoundCameras = allCameras.getNotDiscovered(discoCams: cameras)
        
    }
    func reset(){
        lock.lock()
        cameras.removeAll()
        allCameras.reset()
        nofoundCameras.removeAll()
        cameraGroups.reset()
        recentlyDiscoveredCameras.removeAll()
        lock.unlock()
        
    }
    func removeCamera(camera: Camera){
        lock.lock()
        
        var ci = -1
        for i in 0...cameras.count-1{
            let cam = cameras[i]
            if cam.id == camera.id{
                ci = i
                break
            }
        }
        if ci != -1 {
            cameras.remove(at: ci)
        }
        
        if recentlyDiscoveredCameras.count > 0 {
            ci = -1
            for i in 0...recentlyDiscoveredCameras.count-1{
                let cam = recentlyDiscoveredCameras[i]
                if cam.id == camera.id{
                    ci = i
                    break
                }
            }
            if ci != -1 {
                recentlyDiscoveredCameras.remove(at: ci)
            }
        }
        
        allCameras.reset()
        allCameras.loadFromXml()
        
        cameraGroups.removeFromExistingGroup(camera: camera)
        
        
        lock.unlock()
    }
    func hasCameras() -> Bool {
        return cameras.count > 0
    }
    func hasStandardCameras() -> Bool{
        for cam in cameras{
            if cam.isNvr() == false{
                return true
            }
        }
        
        return false
    }
    func hasNvr() -> Bool {
        for cam in cameras{
            if cam.isNvr(){
                return true
            }
        }
        
        return false
    }
    //MARK: Groups
    var favsFilter: CameraGroup?
    func getFavCamerasForGroup(cameraGrp: CameraGroup)-> [Camera]{
        var favs = [Camera]()
        let camsToUse = getCamerasForGroup(cameraGrp: cameraGrp)
        
        for cam in camsToUse{
            if cam.isAuthenticated() == false{
                continue
            }
            if(cam.isNvr()){
                for vcam in cam.vcams{
                    if vcam.isFavorite{
                        if favExists(favs: favs, cam: vcam) == false{
                            if favs.count < MAX_FAVS{
                                favs.append(vcam)
                            }
                        }
                    }
                }
            }else if cam.isFavorite{
                if favExists(favs: favs, cam: cam) == false{
                    if favs.count < MAX_FAVS{
                        favs.append(cam)
                    }
                }
            }
        }
        return favs
    }
    private func favExists(favs: [Camera],cam: Camera) -> Bool{
        for fav in favs{
            if fav ==  cam{
                return true
            }
        }
        return false
    }
    func getDiscoveredCount() -> Int{
        var count = 0
        for cam in cameras{
            if cam.isZombie == false{
                count += 1
            }
        }
        return count
    }
    func getCamerasForGroup(cameraGrp: CameraGroup)-> [Camera]{
        if cameraGrp.isNvr{
            let nvrCam = cameraGrp.cameras[0]
            return nvrCam.getVCams()
        }
        var cams = [Camera]()
        for camip in cameraGrp.cameraIps{
            if let cam = getCameraForIp(ipa: camip){
                cams.append(cam)
            }
        }
        return cams;
    }
    private func getCameraForIp(ipa: String) -> Camera?{
        for cam in cameras{
            if cam.getBaseFileName() == ipa{
                return cam
            }
        }
        return nil
    }
    func getUndiscoveredCameras() -> [Camera]{
        return allCameras.getNotDiscovered(discoCams: cameras)
    }
    func getAuthenticatedFavorites() -> [Camera]{
        var authFavs = [Camera]()
        let favs = getFavourites()
        for fav in favs{
            if fav.isAuthenticated(){
                if authFavs.count < MAX_FAVS{
                    authFavs.append(fav)
                }
            }
        }
        return authFavs
    }
    func getFavourites() -> [Camera]{
        if favsFilter != nil{
            return getFavCamerasForGroup(cameraGrp: favsFilter!)
        }
        var favs = [Camera]()
        
        for cam in cameras{
            if(cam.isNvr()){
                for vcam in cam.vcams{
                    if vcam.isFavorite{
                        favs.append(vcam)
                    }
                }
            }else if cam.isFavorite{
                favs.append(cam)
            }
        }
        return favs
    }
    func cameraExists(xAddr: String) -> Bool{
        if cameras.count == 0 {
            return false
        }
        for i in 0...cameras.count-1 {
            if cameras[i].xAddr ==  xAddr {
                return true
            }
        }
        return false
    }
    func sortByDisplayOrder(){
        let cams = cameras
        cameras = cams.sorted {
            $0.displayOrder < $1.displayOrder
        }
    }
    //MARK: Zombie cameras
    func getZombieCameras() -> [Camera]{
        var zombieCams = [Camera]()
        for cam in cameras{
            
            var found = false
            for rcam in recentlyDiscoveredCameras{
                if rcam.xAddr == cam.xAddr{
                    found = true
                    break
                }
            }
            if !found{
                zombieCams.append(cam)
                cam.isZombie = true
            }else{
                cam.isZombie = false
            }
            cam.flagChanged()
            
         
        }
        return zombieCams
    }
    func addRecentlyDicovered(camera: Camera){
        lock.lock()
        for cam in recentlyDiscoveredCameras{
            if cam == camera {
                lock.unlock()
                return
            }
        }
        print("OnvifDisco:addRecentlyDicovered",camera.xAddr)
        recentlyDiscoveredCameras.append(camera)
        lock.unlock()
    }
    //MARK: add discovered camera
    func addCamera(camera: Camera,isVcam: Bool = false){
        if isVcam {
            for cam in cameras {
                if cam == camera {
                    print("DiscoveredCameras:addCamera VCAM exists",camera.id,camera.name)
                    return;
                }
            }
            lock.lock()
            cameras.append(camera)
            
            print("DiscoveredCameras:addCamera VCAM",camera.name,camera.isAuthenticated())
            
            listener?.cameraAdded(camera: camera)
            
            lock.unlock()
            
        }else{
            DispatchQueue.main.async{
                self.addCameraImpl(camera: camera)
            }
        }
    }
    private func addCameraImpl(camera: Camera){
        if(camera.id > 0){
            print("DiscoveredCameras:addCamera exists",camera.id,camera.name)
            
        }else{
            lock.lock()
            
            for cam in cameras {
                if cam.xAddr == camera.xAddr {
                    print("OnvifDisco:addCamera, already have matching xAddr",cam.xAddr)
                    lock.unlock()
                    return
                }
                
                //possible cause of crash
                /*
                else if camera.wsaAddr.isEmpty == false &&
                    allCameras.checkWasAddr(addr1: camera.wsaAddr, addr2: cam.wsaAddr){
                    
                    print("was match, updating IP address",cam.getDisplayAddr(),camera.getDisplayAddr())
                    
                    cam.updateCamera(other: camera)
                    
                    lock.unlock()
                    return
                }
                 */
            }
            
            camera.id = cameras.count + 1
            print("DiscoveredCameras:addCamera",camera.xAddr,camera.id)
            cameras.append(camera)
            cameraGroups.cameraAdded(camera: camera)
            
            DispatchQueue.main.async{
                self.sortByDisplayOrder()
            }
            
            print("DiscoveredCameras:addCamera",camera.name,camera.isAuthenticated())
            
            listener?.cameraAdded(camera: camera)
            
            lock.unlock()
        }
        nofoundCameras = allCameras.getNotDiscovered(discoCams: cameras)
        
        
    }
    func cameraUpdated(camera: Camera){
        listener?.cameraChanged(camera: camera)
        camera.flagChanged()
    }
    
    func isMulticamAvailable() -> Bool {
        var authCount = 0
        for cam in cameras {
            if cam.isAuthenticated() {
                authCount += 1
            }
        }
        return authCount > 1
    }
}
class OnvifAuth{
    var nonce64: String = ""
    var creationTime: String = ""
    var passwordDigest: String = ""
    
    init(password: String,cameraTime: Date){
        
        var nonce = Data()//generateNonce(lenght: 16)
        var nonce_b = [UInt8]()
        for i in 0...15{
            let randomInt = Int.random(in: 0..<254)
            let ui8 = UInt8(randomInt)
            nonce.append(ui8)
            nonce_b.append(ui8)
        }
        /*
        print("nonce len",String(nonce.count))
        for i in 0...nonce.count-1{
            print(String(nonce[i]))
        }
         */
        
        nonce64 = Data(nonce).base64EncodedString()
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        creationTime = df.string(from: cameraTime)
        let date_b = creationTime.uint8Array()
        let password_b = password.uint8Array()
        
        
        var combined = [UInt8]()
        combined = appendToUInt8Array(array: combined,toAppend: nonce_b)
        combined = appendToUInt8Array(array: combined,toAppend: date_b)
        combined = appendToUInt8Array(array: combined,toAppend: password_b)
        
        passwordDigest = sha1Base64(data: combined)
        /*
        print("--ONVIF AUTH--")
        print("string password = \""+password+"\";")
        print("string nonce = \""+nonce64+"\";")
        print("string date = \""+creationTime+"\";")
        print("string swiftDigest = \""+passwordDigest+"\";")
        print("-- --")
        */
    }
    func appendToUInt8Array(array: [UInt8],toAppend: [UInt8]) -> [UInt8]
    {
        var combined = array
        for i in 0...toAppend.count-1 {
            combined.append(toAppend[i])
        }
        
        return combined
    }
    func generateNonce(lenght: Int) -> Data {
        //Password_Digest = Base64 ( SHA-1 ( data ) )
        let nonce = NSMutableData(length: lenght)
        let result = SecRandomCopyBytes(kSecRandomDefault, nonce!.length, nonce!.mutableBytes)
        if result == errSecSuccess {
            return nonce! as Data
        } else {
            return Data()
        }
    }
    //Base64 ( SHA-1 ( data ) )
    func sha1Base64(data: [UInt8]) -> String {
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        
        let base64str = Data(digest).base64EncodedString()
        return base64str
        //let hexBytes = digest.map { String(format: "%02hhx", $0) }
        //return hexBytes.joined()
    }
    func generateDigestShA1(data: Data) -> String {
        var digest = [UInt8](repeating: 0, count:Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &digest)
        }
        
        let base64str = Data(digest).base64EncodedString()
        return base64str
     
    }
}
class OnvifDisco : NSObject, GCDAsyncUdpSocketDelegate{
    
    //need to make this observable some how
    var cameras = DiscoveredCameras()
    //var allCameras = AllCameras()
    
    var camerasFound: Bool = false
    
    var ssdpPacket: String = ""
    var soapHeader: String = ""
    //var soapHeaderBasic: String = ""
    var soapSystemTime: String = ""
    var soapCapabilities: String = ""
    var soapProfiles: String = ""
    var soapProfile: String = ""
    var soapSreaminUri: String = ""
    var soapDeviceInfo: String = ""
    var soapPtzPresets: String = ""
    var soapPtzPresetFunc: String = ""
    var soapSetPtzPresets: String = ""
    
    //ptz
    var soapPtz: String = ""
    var soapPtzStop: String = ""
    var soapZoom: String = ""
    var soapZoomStop: String = ""
   
    //Imaging
    var soapImaging: String = ""
    var soapImagingSettings: String = ""
    var soapImagingApply: String = ""
    
    //Admin & Device info
    var soapDeviceFunc: String = ""
    var soapModifyUser: String = ""
    var soapCreateUser: String = ""
    var soapDeleteUser: String = ""
    
    var networkUnavailable: Bool = false
    static var networkErrorFirstTime: Bool = true
    var numberOfDiscos = 0
    
    var abort = false
   
    func flushAndRestart(){
        abort = true
        cameras.reset()
        cameras.allCameras.loadFromXml()
        let dq = DispatchQueue(label: "disco_reboot")
        sq.asyncAfter(deadline: .now() + 0.4,execute:{
            self.start()
            self.ignoreNext = true
        })
    }
    func prepare(){
        
        abort = false
        networkUnavailable = false
        
        ssdpPacket = getXmlPacket(fileName: "ssdp")
        soapSystemTime = getXmlPacket(fileName: "soap_system_time")
        soapHeader = getXmlPacket(fileName: "soap_header")
        soapProfile = getXmlPacket(fileName: "soap_profile")
        soapCapabilities = getXmlPacket(fileName: "soap_capabilities")
        soapProfiles = getXmlPacket(fileName: "soap_profiles")
        soapDeviceInfo = getXmlPacket(fileName: "soap_device_info")
        soapSreaminUri = getXmlPacket(fileName: "soap_stream_uri")
        
        //PTZ Presets
        soapPtzPresets = getXmlPacket(fileName: "soap_ptz_presets")
        soapPtzPresetFunc = getXmlPacket(fileName: "soap_goto_ptz_preset")
        soapSetPtzPresets = getXmlPacket(fileName: "soap_set_ptz_preset")
        
        //ptz
        soapPtz = getXmlPacket(fileName: "soap_ptz")
        soapPtzStop = getXmlPacket(fileName: "soap_ptz_stop")
        soapZoom = getXmlPacket(fileName: "ptz_zoom")
        soapZoomStop = getXmlPacket(fileName: "ptz_zoom_stop")
        
        //Imaging
        soapImaging = getXmlPacket(fileName: "soap_imaging")
        soapImagingSettings = getXmlPacket(fileName: "soap_imaging_settings")
        soapImagingApply = getXmlPacket(fileName: "soap_imaging_apply")
        
        //Admin
        soapDeviceFunc = getXmlPacket(fileName: "soap_device_func")//generic can be used for device_info
        soapModifyUser = getXmlPacket(fileName: "soap_modify_user")
        soapCreateUser = getXmlPacket(fileName: "soap_create_user")
        soapDeleteUser = getXmlPacket(fileName: "soap_delete_user")
    }
    
    func getXmlPacket(fileName: String) -> String{
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                print("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
    
    func addListener(listener: DiscoveryListener){
        cameras.listener  = listener
    }
    
    var authListener: AuthenicationListener?
    var isAuthenticating = false
    
    func startAuthorized(camera: Camera,authListener: AuthenicationListener){
        
        print("--- ONVIF START AUTH -- ")
        print("auth",camera.user,camera.password)
        prepare()
        self.authListener = authListener
        self.isAuthenticating = true
        //clear previous fault flags
        camera.authFault = ""
        
        getSystemTime(camera: camera,callback: handleGetSystemTime)
    }
    
    var ssdpSocket: GCDAsyncUdpSocket?
    let sq = DispatchQueue(label: "onvif_disco")
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "network")
    
    
    var ignoreNext = false
    
    func start(){
        if ignoreNext{
            
            ignoreNext = false
            return
        }
        
        sq.async {
            self.startImpl()
        }
    }
    func startImpl(){
        
        prepare()
        //transient for this parser
        cameras.recentlyDiscoveredCameras = [Camera]()
        
        doUnicastDisco()
        
        numberOfDiscos += 1
        
        let ssdpAddres = "239.255.255.250"
        let port:UInt16 = 3702
        let ssdpPort:UInt16 = 5820
        
        print("Starting OnvifDisco");
        logger.log("Creating GCDAsyncUdpSocket")
        ssdpSocket = GCDAsyncUdpSocket(delegate: self,delegateQueue: DispatchQueue.main)
         
       if let soapPacket = ssdpPacket.data(using: .ascii){
             
            //bind for responses
            do {
                
                try ssdpSocket!.enableReusePort(true)
                logger.log("sdpSocket.bind")
                
                logger.log("enableBroadcast")
                do { try ssdpSocket!.enableBroadcast(true)} catch {
                    print("enableBroadcast not proceed",error)
                    logger.log("enableBroadcast failed")
                }
                
                try ssdpSocket!.bind(toPort: ssdpPort)
                
                
            } catch {
                print("bindToPort not proceed",error)
                logger.log("bindToPort not proceed")
                //print("OnvifDisco aborted")
                //return
            }
            
            
 
            logger.log("invoke joinMulticastGroup")
            do { try ssdpSocket!.joinMulticastGroup(ssdpAddres)} catch {
                print("joinMulticastGroup not proceed",error)
                logger.log("joinMulticastGroup failed")
            }
            
           /*
            logger.log("invoke connect")
            do { try ssdpSocket!.connect(toHost: ssdpAddres, onPort: ssdpPort)} catch {
                print("connect not proceed",error)
                logger.log("connect failed")
            }
            */
            
            
            logger.log("invoke beginReceiving")
            do { try ssdpSocket!.beginReceiving()} catch {
                print("beginReceiving not proceed",error)
                logger.log("beginReceiving failed")
            }
            
           
            print("isConnected: ",ssdpSocket!.isConnected())
            //SsdpSend.run(soapPacket: ssdpPacket)
         
            //startSsdp()
            ssdpSocket!.send(soapPacket,toHost: ssdpAddres,port: port, withTimeout: 5, tag: 0)
        }
        
        print("sockets ready");
        
        let q = DispatchQueue(label: "disco_wait")
        q.async() {
            for i in 0...9 {
                sleep(1)
                if self.networkUnavailable || self.abort{
                    break
                }
            }
            print("Disco timeout with error?",self.networkUnavailable)
            let socket = self.ssdpSocket!
            if socket.isClosed() == false {
                socket.close()
            }
            
            let zombieCams = self.cameras.getZombieCameras()
            for zombie in zombieCams{
                self.pingZombie(nfc: zombie)
            }
            
            self.cameras.listener?.discoveryTimeout()
            
            
        }
        
    }
    
    //MARK: Check WAN cams for Zombie status
    func pingZombie(nfc: Camera){
        nfc.timeCheckOk = false
        getSystemTime(camera: nfc, callback: handlePingZombie)
    }
    func handlePingZombie(camera:Camera){
        if camera.timeCheckOk {
            print("Zombie ping OK",camera.getDisplayAddr())
            cameras.addRecentlyDicovered(camera: camera)
            camera.isZombie = false
            camera.flagChanged()
            cameras.listener?.zombieStateChange(camera: camera)
        }
    }
    
    //MARK: Unicast
    func doUnicastDisco(){
        // try previously auth cameras via unicast
        let undisco = cameras.getUndiscoveredCameras()
        for nfc in undisco{
            
            
            if nfc.isVirtual{
                print("doUnicast skip",nfc.getDisplayAddr(),nfc.getDisplayName())
                continue
            }
            
            nfc.timeCheckOk = false
            nfc.id = -1
            
            if nfc.xAddr.isEmpty == false{
                print("Trying unicast on previously disco",nfc.name)
                getSystemTime(camera: nfc, callback: handleUnicastGetSystemTime)
            }else{
                print("Executing legacy unicast on previously disco",nfc.name)
                
                
                let discoXmlFn = nfc.getBaseFileName() + "_disco.xml"
                print("undisco",nfc.getDisplayName(),nfc.xAddr)
                let discoXmlPath = FileHelper.getPathForFilename(name: discoXmlFn)
                do{
                    let xml = try String(contentsOfFile: discoXmlPath.path,encoding: .utf8)
                    let discoParser = DiscoveryParser()
                    discoParser.parseRespose(xml: xml.data(using: .utf8)!)
                    nfc.xAddr = discoParser.xAddr
                    nfc.loadCredentials()
                    //if nfc.user.isEmpty ==  false{
                        print("Trying unicast on previously disco",nfc.name)
                        getSystemTime(camera: nfc, callback: handleUnicastGetSystemTime)
                    //}
                
                }catch{
                    print("Unable to load undisco file",discoXmlFn)
                }
            }
        }
    }
    func handleUnicastGetSystemTime(camera: Camera){
        print("Handle unicast got systemTime ",camera.name,camera.connectTime)
        if camera.timeCheckOk {
            cameras.addRecentlyDicovered(camera: camera)
            cameras.addCamera(camera: camera)
            
            //if this is an imported camera then we need to load up the missing XML
            if camera.profiles.count==0{
                getDeviceInfo(camera: camera,callback: handleGetDeviceInfo)
            }
        }
     
    }
    //MARK: UdpSocket
    func udpSocketDidClose(_ sock: GCDAsyncUdpSocket, withError error: Error?) {
        NSLog("udpSocketDidClose %@", "\(error)")
        if error != nil {
            var errMsg = error!.localizedDescription
            
            networkUnavailable = true
           
            self.cameras.listener?.networkNotAvailabled(error: errMsg)
        }
        logger.log("udpSocketDidClose")
        
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) {
        print("didSendDataWithTag")
        logger.log("didSendDataWithTag")
        self.networkUnavailable = false
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
        print("Unable to send data",error)
        logger.log("Unable to send data")
        //cameras.listener?.discoveryError(error: "Unable to send data to network")
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) {
        print("didConnectToAddress")
        logger.log("didConnectToAddress")
        //cameras.listener?.discoveryError(error: "Failed to connect via UDP")
    }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) {
        print("did not connect",error)
        logger.log("did not connect")
        
       
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
          //print("incoming packet: \(data)");
        
        if abort{
            logger.log("incoming packet ignored, abort == true")
            
            return
        }
        logger.log("incoming packet")
        
        let discoParser = DiscoveryParser()
        discoParser.parseRespose(xml: data)
        
        let camName = discoParser.camName
        let xAddr = discoParser.xAddr
        if xAddr.isEmpty{
            logger.log("incoming packet ignored, xAddr.isEmpty")
            
            return
        }
        var camera = Camera(id: 0)
        
        camera.name = camName.htmlDecoded
        camera.makeModel = camName
        camera.xAddr = xAddr
        
        //was address for checking previous saved state at different endpoints
        if discoParser.urn.isEmpty == false{
            //print("Onvif:urn",xAddr,discoParser.urn)
            camera.wsaAddr = discoParser.urn
            
            //safety first
            if(Camera.IS_NXV_PRO){
                camera = cameras.allCameras.getExistingCamera(discoCamera: camera)
            }
        }
        
        //transient non-ui always add
        cameras.addRecentlyDicovered(camera: camera)
        
        //check if we have already been discovered
        if cameras.cameraExists(xAddr: xAddr) {
            print("Discovered existing camera",xAddr)
            //last discovered timestamp ?
            
            return;
        }
        
        let str = String(decoding: data, as: UTF8.self)
        
        saveSoapPacket(endpoint: URL(string: camera.xAddr)!,method: "disco", xml: str)
       
        //next try to get capabilities
        print("--- DISCOVERED -- ")
        getSystemTime(camera: camera,callback: handleGetSystemTime)
    }
    
    func handleGetCapabilities(camera: Camera){
        print("Handle got capabilities ",camera.name)
        
        camerasFound = true
        //entry point for valid cameras
        cameras.addCamera(camera: camera)
       //make sure the camera has a name updated in the UI
        self.cameras.cameraUpdated(camera: camera)
       
        queryProfiles(camera: camera,callback: handleGetPrfiles)
    }
    func handleGetSystemTime(camera: Camera){
        print("Handle got systemTime ",camera.name,camera.connectTime)
        
        getDeviceInfo(camera: camera, callback: handleGetDeviceInfo)
     
    }
    func handleGetDeviceInfo(camera: Camera){
        print("Handle got device info ",camera.name)
        
        self.cameras.cameraUpdated(camera: camera)
        
        if(camera.authFault.isEmpty){            
            getCapabilities(camera: camera, callback: handleGetCapabilities)
        }else{
            print("handleGetDeviceInfo abort with fault",camera.authFault)
            //entry point for valid cameras
            cameras.addCamera(camera: camera)
           //make sure the camera has a name updated in the UI
            self.cameras.cameraUpdated(camera: camera)
            self.authListener?.cameraAuthenticated(camera: camera, authenticated: false)
        }
    }
    func handleGetPrfiles(camera: Camera){
        print("Handle got profiles ",camera.name)
        print("Camera authenticated",camera.authenticated)
       
        if(camera.isAuthenticated() ==  false){
            print("Auth failed",camera.authFault)
            if isAuthenticating{
                self.authListener?.cameraAuthenticated(camera: camera,authenticated: false)
            }
        }else{
            queryProfile(camera: camera, profileIndex: 0, callback: handleGetProfile)
            //self.authListener?.cameraAuthenticated(camera: camera, authenticated: true)
        }
    }
    func handleGetProfile(camera: Camera,profileIndex: Int){
        if camera.profiles.count == 0 {
            print("handleGetProfile no prfiles",camera.name,profileIndex)
            camera.flagChanged()
            return
        }
        print("handleGetProfile",camera.name,profileIndex,camera.profiles.count)
        
        if(profileIndex+1 < camera.profiles.count){
            queryProfile(camera: camera, profileIndex: profileIndex+1, callback: handleGetProfile)
        }else{
            queryStreamUri(camera: camera, profileIndex: 0, callback: handleGetStreamUri)
            
            if profileIndex > 0 && isAuthenticating {
                camera.selectBestProfile()
            }
            if(camera.profileIndex == -1){
                camera.profileIndex = 0
            }
            camera.save()
            camera.flagChanged()
        }
    }
    func handleGetStreamUri(camera: Camera,profileIndex: Int){
        print("handleGetStreamUri",camera.name,profileIndex)
        if(profileIndex+1 < camera.profiles.count){
            queryStreamUri(camera: camera, profileIndex: profileIndex+1, callback: handleGetStreamUri)
        }else{
            //callback is StartAuth entry point
            camera.flagChanged()
            self.authListener?.cameraAuthenticated(camera: camera, authenticated: camera.isAuthenticated() && camera.hasProfileUri())
        }
    }
    func addAuthHeader(camera: Camera,soapPacket: String) -> String{
        
        
        if camera.password.isEmpty {
            return soapPacket
        }
        //camera.connectTime = Date()
        
        var sp = ""
        let auth = OnvifAuth(password: camera.password, cameraTime: camera.connectTime)
    
        sp = String(utf8String: soapHeader.cString(using: .utf8)!)!
        sp = sp.replacingOccurrences(of: "_USERNAME_", with: camera.user)
        sp = sp.replacingOccurrences(of: "_PWD_DIGEST_", with: auth.passwordDigest)
        sp = sp.replacingOccurrences(of: "_NONCE_", with: auth.nonce64)
        sp = sp.replacingOccurrences(of: "_TIMESTAMP_", with: auth.creationTime)
    
        var packetWithAuth = "";//"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        
        
        let cleanSoapPacket = soapPacket.replacingOccurrences(of: "\r\n",with: "\n")
        let lines = cleanSoapPacket.components(separatedBy: "\n");
        packetWithAuth += lines[0]//.trimmingCharacters(in: CharacterSet.newlines)
        packetWithAuth += "\n"
        packetWithAuth += sp
        for i in 1...lines.count-1{
            packetWithAuth += lines[i]//.trimmingCharacters(in: CharacterSet.newlines)
            packetWithAuth += "\n"
        }
        return packetWithAuth
    }
    func getSystemTime(camera: Camera,callback:@escaping (Camera) -> Void){
        let action = "http://www.onvif.org/ver10/device/wsdl/GetSystemDateAndTime"
        let apiUrl = URL(string: camera.xAddr)!
        
        let soapPacket=addAuthHeader(camera: camera,soapPacket: soapSystemTime)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let configuration = URLSessionConfiguration.default
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
                let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                camera.timeCheckOk = false
                print(error?.localizedDescription ?? "No data")
                return
            }else{
               
                camera.timeCheckOk = true
                
                let parser = SystemTimeParser()
                parser.parseRespose(xml: data!)
                
                camera.connectTime = parser.sysDateTime
                
                if self.isAuthenticating == false {
                    print("LOAD CREDS",camera.name)
                    camera.loadCredentials()
                }
                callback(camera)
            }
            
        }

        task.resume()

    }
    /*
    func getDeviceInfo(camera: Camera,callback:@escaping (Camera) -> Void){
        
        let action = "http://www.onvif.org/ver10/device/wsdl/GetDeviceInformation";
        let apiUrl = URL(string: camera.xAddr)!
        
        let soapPacket = addAuthHeader(camera: camera, soapPacket: soapDeviceInfo).replacingOccurrences(of: "\r", with: "")
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        //let contentLen  = String(soapPacket.count)
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                callback(camera)
                print(error?.localizedDescription ?? "No data")
                if self.isAuthenticating{
                    self.authListener?.cameraAuthenticated(camera: camera, authenticated: false)
                }
                return
            }else{
               
                let resp = String(data: data!, encoding: .utf8)
                self.saveSoapPacket(endpoint: apiUrl, method: "device_info", xml: resp!)
                
                
                //check for :Fault
                //set camera.authFault =
                
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    camera.authenticated = false
                    camera.authFault = parser.authFault.trimmingCharacters(in: CharacterSet.whitespaces)
                    //self.saveSoapPacket(method: camera.name+"_device_info_err", xml: soapPacket)
                    
                }else{
                    let tags = ["Model","Manufacturer"]
                    let infoParser = MultiTagParser(keys: tags)
                    infoParser.parseRespose(xml: data!)
                    for i in 0...infoParser.vals.count-1 {
                        if infoParser.vals[i].isEmpty == false {
                            camera.makeModel = infoParser.vals[i].htmlDecoded
                            if camera.name.isEmpty || camera.name == Camera.DEFUALT_NEW_CAM_NAME{
                                camera.name = camera.makeModel
                                
                                if self.isAuthenticating == false {
                                    camera.loadCredentials()
                                }
                            }else if camera.name.contains(camera.makeModel) == false {
                                camera.name = camera.name + " " + camera.makeModel
                            }
                            break
                        }
                    }
                    
                    
                    self.cameras.cameraUpdated(camera: camera)
                }
                callback(camera)
            }
            
        }

        task.resume()
    }
    */
    func queryStreamUri(camera: Camera,profileIndex: Int,callback:@escaping (Camera,Int) -> Void){
        
        print("queryStreamUri",camera.name,profileIndex,camera.profiles.count)
        
        let action = "http://www.onvif.org/ver10/media/wsdl/GetStreamUri";
        let apiUrl = URL(string: camera.mediaXAddr)!
        
        //add auth header
        let cp = camera.profiles[profileIndex]
        let profilePacket = soapSreaminUri.replacingOccurrences(of: "_PROFILE_TOKEN_", with: cp.token)
        let soapPacket=addAuthHeader(camera: camera,soapPacket: profilePacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
                let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
              
                print(error?.localizedDescription ?? "No data")
                
                return
            }else{
                //assume already authenticated so skip fault checking
                let resp = String(data: data!, encoding: .utf8)
                self.saveSoapPacket(endpoint: apiUrl,method: "get_stream_uri"+String(profileIndex), xml: resp!)
                
                let parser = SingleTagParser(tagToFind: "tt:Uri")
                parser.parseRespose(xml: data!)
                
                if parser.tagFound  {
                    if profileIndex >= camera.profiles.count {
                        print("EX>>>queryStreamUri",camera.name,profileIndex,camera.profiles.count);
                       
                    }else{
                        let xmlIpa = URL(string: parser.result)!.host!
                        var serviceIpa =  URL(string: camera.xAddr)!.host!
                        
                        if(xmlIpa != serviceIpa){
                            print("XAddrParser updating IP",xmlIpa,serviceIpa)
                            let xAddr = parser.result.replacingOccurrences(of: xmlIpa, with: serviceIpa)
                            camera.profiles[profileIndex].url = xAddr
                        }else{
                            camera.profiles[profileIndex].url = parser.result
                        }
                    }
                }
                
                
                callback(camera,profileIndex)
            }
        }
    
        task.resume()
    }
    
    func queryProfile(camera: Camera,profileIndex: Int,callback:@escaping (Camera,Int) -> Void){
        let action = "http://www.onvif.org/ver10/media/wsdlGetProfile";
        let apiUrl = URL(string: camera.mediaXAddr)!
        
        //add auth header
        let cp = camera.profiles[profileIndex]
        let profilePacket = soapProfile.replacingOccurrences(of: "_PROFILE_TOKEN_", with: cp.token)
        let soapPacket=addAuthHeader(camera: camera,soapPacket: profilePacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let configuration = URLSessionConfiguration.default
        //configuration.timeoutIntervalForRequest = 10
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
                let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                return
            }else{
                //assume already authenticated so skip fault checking
                let resp = String(data: data!, encoding: .utf8)
                self.saveSoapPacket(endpoint: apiUrl,method: "get_profile_"+String(profileIndex), xml: resp!)
                
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
                
                
                let zoomParser = ZoomRangeProfileXmlParser()
                zoomParser.parseRespose(xml: data!)
                
                if zoomParser.tokenVals[0].isEmpty == false {
                    cp.zoomRange = [zoomParser.tokenVals[0],zoomParser.tokenVals[1]]
                }
                
               
                
                
                callback(camera,profileIndex)
            }
        }
    
        task.resume()
    }
    func queryProfiles(camera: Camera,callback:@escaping (Camera) -> Void){
        let action = "http://www.onvif.org/ver10/media/wsdl/GetProfiles"
        guard let apiUrl = URL(string: camera.mediaXAddr) else{
            print("queryProfiles missing mediaXAddr",camera.getBaseFileName())
            authListener?.cameraAuthenticated(camera: camera, authenticated: false)
            return
        }
        
        //add auth header
        let soapPacket=addAuthHeader(camera: camera,soapPacket: soapProfiles)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
                let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                return
            }else{
               
                if let resp = String(data: data!, encoding: .utf8){
                    self.saveSoapPacket(endpoint: apiUrl,method: "get_profiles", xml: resp)
                }
               
                
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    camera.authenticated = false
                    camera.authFault = parser.authFault.trimmingCharacters(in: CharacterSet.whitespaces)
                    self.authListener?.cameraAuthenticated(camera: camera, authenticated: false)
                    callback(camera)
                    return
                }
                //let resp = String(data: data!, encoding: .utf8)
                //self.saveSoapPacket(method: "get_profiles", xml: resp!)
                
                let profileParser = ProfileXmlParser()
                profileParser.parseRespose(xml: data!)
                
                camera.profiles = profileParser.profiles
                
                camera.authenticated = true
                camera.flagChanged()
                callback(camera)
                
                if Camera.IS_NXV_PRO{
                    self.doExtraQueries(camera: camera)
                }
            }
            
        }

        task.resume()
    }
    func getCapabilities(camera: Camera,callback:@escaping (Camera) -> Void){
        
        
        let soapPacket=addAuthHeader(camera: camera,soapPacket: soapCapabilities)
       
        let action = "http://www.onvif.org/ver10/device/wsdl/GetCapabilities";
        
        let apiUrl = URL(string: camera.xAddr)!
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil || data == nil{
                print(error?.localizedDescription ?? "No data")
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
                self.saveSoapPacket(endpoint: apiUrl,method: "capabilities", xml: resp!)
                
            
                let faultParser = FaultParser()
                faultParser.parseRespose(xml: data!)
                
                if faultParser.hasFault(){
                    print("--- CAPABILITIES FAULT ---")
                    print(faultParser.authFault,faultParser.faultReason)
                    
                }else{
                    
                    var parser = XAddrParser(tagToFind: "Media",serviceXAddr: camera.xAddr)
                    parser.parseRespose(xml: data!)
                    
                    camera.mediaXAddr = parser.xAddr
                    
                    parser = XAddrParser(tagToFind: "PTZ",serviceXAddr: camera.xAddr)
                    parser.parseRespose(xml: data!)
                    
                    camera.ptzXAddr = parser.xAddr
                    
                    parser = XAddrParser(tagToFind: "Imaging",serviceXAddr: camera.xAddr)
                    parser.parseRespose(xml: data!)
                    camera.imagingXAddr = parser.xAddr
                    
                    print("camera.mediaXAddr",camera.mediaXAddr,camera.ptzXAddr)
                    
                    callback(camera)
                }
            }
            
        }

        task.resume()
        
    }
    
    //MARK: PTZ
    func sendPtzZoomRequest(zoomIn: Bool,action: String,token: String,xInc: Double,camera: Camera){
        
        var x = xInc
        if x == 0 {
            x = 0.5
        }
        if zoomIn ==  false {
            x *= -1
        }
        
        var soapPacket = soapZoom
        soapPacket = soapPacket.replacingOccurrences(of: "__PROFILE__",with: token);
        soapPacket = soapPacket.replacingOccurrences(of: "__XVAL__", with:  String(x));
        
        sendPtzRequest(camera: camera, action: action, sp: soapPacket)
        
    }
    func sendPtzStartCommand(camera: Camera,cmd: PtzAction){
        let action = "http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove";
         
        guard let profile = camera.selectedProfile() else{
            print("sendPtzStartCommand missing camera profile")
            return
        }
        let token = profile.token
        
        if cmd == PtzAction.zoomin || cmd == PtzAction.zoomout {
            var zInc = 0.0
            if profile.ptzSpeeds[2].isEmpty == false {
                zInc = Double(profile.ptzSpeeds[2])!
            
                sendPtzZoomRequest(zoomIn: (cmd == PtzAction.zoomin),action: action,token: token,xInc: zInc,camera: camera)
            }
            return
        }
        if profile.ptzSpeeds[0].isEmpty {
            //NSSound.beep()
            return;
        }
        
        var xInc = Double(profile.ptzSpeeds[0])!
        var yInc = Double(profile.ptzSpeeds[1])!
        var x = 0.0
        var y = 0.0
        
        if xInc == 0{
            xInc = 0.1
        }else if (xInc < 0.5)
        {
            xInc = 0.5;
        }
        if yInc == 0{
            yInc = 0.1
            
        }else if (yInc < 0.5)
        {
            yInc = 0.5;
        }
        switch cmd{
        case PtzAction.up:
                y = yInc
                break
        case PtzAction.down:
                y = yInc * -1
                break
        case PtzAction.left:
                x = xInc * -1
                break
        case PtzAction.right:
                x = xInc;
                break
           
        default:
            break
        }
        var soapPacket = soapPtz
        soapPacket = soapPacket.replacingOccurrences(of: "__PROFILE__",with: token);
        soapPacket = soapPacket.replacingOccurrences(of: "__XVAL__", with:  String(x));
        soapPacket = soapPacket.replacingOccurrences(of: "__YVAL__", with: String(y));

        sendPtzRequest(camera: camera, action: action, sp: soapPacket)
    }
    func sendPtzStopCommand(camera: Camera,isZoom: Bool){
          
        let action = "http://www.onvif.org/ver20/ptz/wsdl/stop";
        guard let profile = camera.selectedProfile() else{
            print("sendPtzStopCommand missing camera profile")
            return
        }
        let token = profile.token
        
        var soapPacket = isZoom ? soapZoomStop : soapPtzStop
        soapPacket = soapPacket.replacingOccurrences(of: "__PROFILE__",with: token);
        
        sendPtzRequest(camera: camera, action: action, sp: soapPacket)
    }
    func sendPtzRequest(camera: Camera,action: String,sp: String){
       
        let soapPacket = addAuthHeader(camera: camera, soapPacket: sp)
       
        //print("sendPtzRequest",camera.ptzXAddr)
        //print(soapPacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
       
        let endpoint = URL(string: camera.ptzXAddr)!
       
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
                
                let fParser = FaultParser()
                fParser.parseRespose(xml: data!)
                if fParser.hasFault(){
                    print("Ptz send fault",fParser.authFault)
                    print(resp)
                }
            }
        }
        task.resume()
    }
    //MARK: Ptz Presets
    func gotoPtzPreset(camera: Camera,presetToken: String, callback: @escaping (Camera,String,Bool) -> Void){
        let pfunc = "GotoPreset"
        let xmlPacket = soapPtzPresetFunc
        _PtzPresetFunc(camera: camera, actionName: pfunc, xmlPacket: xmlPacket, presetToken: presetToken, callback: callback)
    }
    func deletePtzPreset(camera: Camera,presetToken: String, callback: @escaping (Camera,String,Bool) -> Void){
        let pfunc = "RemovePreset"
        let xmlPacket = soapPtzPresetFunc
        _PtzPresetFunc(camera: camera, actionName: pfunc, xmlPacket: xmlPacket, presetToken: presetToken, callback: callback)
    }
    func createPtzPreset(camera: Camera,presetToken: String, callback: @escaping (Camera,String,Bool) -> Void){
        let pfunc = "SetPreset"
        let xmlPacket = soapSetPtzPresets
        _PtzPresetFunc(camera: camera, actionName: pfunc, xmlPacket: xmlPacket, presetToken: presetToken, callback: callback)
    }
    func _PtzPresetFunc(camera: Camera,actionName: String,xmlPacket: String,presetToken: String, callback: @escaping (Camera,String,Bool) -> Void){
        let action = "http://www.onvif.org/ver20/ptz/wsdl/" + actionName
        let endpoint = URL(string: camera.ptzXAddr)!
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
    
        var soapPacket = addAuthHeader(camera: camera, soapPacket: xmlPacket)
        
        let cp = camera.selectedProfile()!
        soapPacket = soapPacket.replacingOccurrences(of: "_FUNC_", with: actionName)
        soapPacket = soapPacket.replacingOccurrences(of: "_PROFILE_TOKEN_", with: cp.token)
        soapPacket = soapPacket.replacingOccurrences(of: "_PRESET_TOKEN_", with: presetToken)
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                callback(camera,"Connect error",false)
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
               
                let faultParser = FaultParser();
                faultParser.parseRespose(xml: data!)
                if faultParser.hasFault(){
                    print("Onvif:gotoPtzPreset",camera.getDisplayAddr(),faultParser.authFault)
                    print(soapPacket)
                    print(resp)
                    callback(camera,faultParser.authFault,false)
                }else{
                    
                    if actionName == "SetPreset"{
                        let xmlParser = XmlPathsParser(tag: ":SetPresetResponse")
                        xmlParser.parseRespose(xml: data!)
                        
                        //print(resp)
                        
                        let flatXml = xmlParser.itemPaths
                        //["tptz:PresetToken/Preset1"]
                        if flatXml.count == 1{
                            let parts = flatXml[0].components(separatedBy: "/")
                            if parts.count == 2{
                                if camera.ptzPresets == nil{
                                    camera.ptzPresets = [PtzPreset]()
                                }
                                let id = camera.ptzPresets!.count
                                let token = parts[1]
                                let newPreset = PtzPreset(id: id, token: token, name: presetToken)
                                
                                camera.ptzPresets!.append(newPreset)
                            }
                        }
                        
                        print(flatXml)
                       
                    }
                    //parse the imaging options
                    callback(camera,"OK",true)
                    print("Ptz preset executed ok")
                }
            }
        }
        resultTask.resume()
        
    }
    func getPtzPresets(camera: Camera,callback: @escaping(Camera,String,Bool)->Void){
        let action = "http://www.onvif.org/ver20/ptz/wsdl/GetPresets"
        let endpoint = URL(string: camera.ptzXAddr)!
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
    
        var soapPacket = addAuthHeader(camera: camera, soapPacket: soapPtzPresets)
        
        let cp = camera.selectedProfile()!
        
        soapPacket = soapPacket.replacingOccurrences(of: "_PROFILE_TOKEN_", with: cp.token)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                callback(camera,"Connect error",false);
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
               
                let faultParser = FaultParser();
                faultParser.parseRespose(xml: data!)
                if faultParser.hasFault(){
                    print("Onvif:getImagingOptions",camera.getDisplayAddr(),faultParser.authFault)
                    print(resp)
                    callback(camera,faultParser.authFault,false);
                }else{
                    //parse the imaging options
                    let presetsParser = XmlPathsParser(tag: ":GetPresetsResponse")
                    presetsParser.attrTag = "token"
                    presetsParser.parseRespose(xml: data!)
                    
                    let flatXml = presetsParser.itemPaths
                    let attribs = presetsParser.attribStack
                    if flatXml.count > 0 && flatXml.count <= attribs.count{
                        camera.ptzPresets = [PtzPreset]()
                        
                        let presetsFactory = PtzPresetsFactory()
                        presetsFactory.parsePresets(xmlPaths: flatXml,attribs: attribs)
                        if presetsFactory.presets.count > 0{
                          
                            /*
                            for p in presetsFactory.presets{
                                camera.ptzPresets!.append(p)
                            }
                             */
                            camera.ptzPresets = presetsFactory.presets
                        }
                        print("Onvif:PtzPresets OK",presetsFactory.presets.count)
                    }else{
                        print("Onvif:PtzPresets Empty",flatXml.count,attribs.count)
                        camera.ptzPresets = [PtzPreset]()
                        
                    }
                    print("PRESETS\n ",flatXml)
                    
                    self.saveSoapPacket(endpoint: endpoint, method: "ptz_presets_"+cp.name, xml: resp!)
                    
                    callback(camera,"OK",true);
                }
            }
        }
        resultTask.resume()
        
    }
    //MARK: Imaging
    
    func getImagingOptions(camera: Camera,callback: @escaping (Camera) -> Void){
        
        let action = "http://www.onvif.org/ver20/imaging/wsdl/GetOptions"
        let endpoint = URL(string: camera.imagingXAddr)!
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
       
        
        var soapPacket = addAuthHeader(camera: camera, soapPacket: soapImaging)
        
        let cp = camera.selectedProfile()!
        
        soapPacket = soapPacket.replacingOccurrences(of: "_VIDEO_SRC_TOKEN_", with: cp.videoSrcToken)
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                //callback(camera,false,nil);
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
               
                let faultParser = FaultParser();
                faultParser.parseRespose(xml: data!)
                if faultParser.hasFault(){
                    print("Onvif:getImagingOptions",camera.getDisplayAddr(),faultParser.authFault)
                }else{
                  
                    self.saveSoapPacket(endpoint: endpoint, method: "imaging_options_"+cp.name, xml: resp!)
                    
                    //next get the actual values
                    self.getImagingSettings(camera: camera,optsResult: data!,callback: callback)
                }
            }
        }
        resultTask.resume()
    }
    
    func getImagingSettings(camera: Camera,optsResult: Data,callback: @escaping (Camera) -> Void){
        let action = "http://www.onvif.org/ver20/imaging/wsdl/GetImagingSettings"
        let endpoint = URL(string: camera.imagingXAddr)!
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
       
        
        var soapPacket = addAuthHeader(camera: camera, soapPacket: soapImagingSettings)
        
        let cp = camera.selectedProfile()!
        
        soapPacket = soapPacket.replacingOccurrences(of: "_VIDEO_SRC_TOKEN_", with: cp.videoSrcToken)
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                //callback(camera,false,nil);
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
               
                let faultParser = FaultParser();
                faultParser.parseRespose(xml: data!)
                if faultParser.hasFault(){
                    print("Onvif:getImagingOptions",camera.getDisplayAddr(),faultParser.authFault)
                }else{
                    
                    
                    let factory = OnvifImagingParser()
                    factory.parseOptions(xml: optsResult)
                    factory.psrseSetting(xml: data!)
                    
                    camera.imagingOpts = factory.imagingOpts
                    
                    callback(camera)
                    self.saveSoapPacket(endpoint: endpoint, method: "imaging_settings_"+cp.name, xml: resp!)
                    
                    //next get the actual values
                    
                }
            }
        }
        resultTask.resume()
    }
    func applyImagingSettings(camera: Camera,callback: @escaping (Camera) -> Void){
        let action = "http://www.onvif.org/ver20/imaging/wsdl/SetImagingSettings"
        let endpoint = URL(string: camera.imagingXAddr)!
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
       
        
        var soapPacket = addAuthHeader(camera: camera, soapPacket: soapImagingApply)
        
        let cp = camera.selectedProfile()!
        
        soapPacket = soapPacket.replacingOccurrences(of: "_VIDEO_SRC_TOKEN_", with: cp.videoSrcToken)
        
        
        var xtraXml = ""
        let indent = "\t\t\t\t"
        
        
        let nio =  camera.imagingOpts!.count
        //for opt in camera.imagingOpts!{
        for i in 0...nio-1{
            let opt = camera.imagingOpts![i]
                opt.dump()
                xtraXml.append(indent)
                xtraXml.append(opt.xmlRep(indent: indent))
                if i < nio-1{
                    xtraXml.append("\n")
                }
        }
    
        soapPacket = soapPacket.replacingOccurrences(of: "_XTRA_XML_", with: xtraXml)
        
        print(soapPacket)
        
        //used to update UI
        camera.imagingFault = ""
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                //callback(camera,false,nil);
                camera.imagingFault = "Failed to save"
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
               
                //print(resp)
                
                let faultParser = FaultParser();
                faultParser.parseRespose(xml: data!)
                if faultParser.hasFault(){
                    camera.imagingFault = faultParser.authFault
                    print("Onvif:applyImagingSettings",camera.getDisplayAddr(),faultParser.authFault)
                    print(resp)
                   callback(camera)
                }else{
                    //need to do both for flat xml parsing
                    self.getImagingOptions(camera: camera, callback: callback)
                }
            }
        }
        resultTask.resume()
    }
    //MARK: User management
    enum AdminFunction{
        case modify,create,delete
    }
    func getUsers(camera: Camera,callback: @escaping(Camera)->Void){
        getDeviceFunc(getFunc: "GetUsers", camera: camera) { camera, xpaths, data in
            CameraUpdater.handleGetUsers(camera:camera,xpaths: xpaths,data: data)
            callback(camera)
            
        }
    }
    func modifyUser(camera: Camera,user: CameraUser,callback: @escaping (Camera,Bool,String) -> Void){
        _userFunc(adminAction: .modify, camera: camera, user: user, callback: callback)
    }
    func createUser(camera: Camera,user: CameraUser,callback: @escaping (Camera,Bool,String) -> Void){
        _userFunc(adminAction: .create, camera: camera, user: user, callback: callback)
    }
    func deleteUser(camera: Camera,user: CameraUser,callback: @escaping (Camera,Bool,String) -> Void){
        _userFunc(adminAction: .delete, camera: camera, user: user, callback: callback)
    }
    private func _userFunc(adminAction: AdminFunction,camera: Camera,user: CameraUser,callback: @escaping (Camera,Bool,String) -> Void){
        var funcAction = ""
        var xmlPacket = ""
        switch adminAction {
        case .modify:
            funcAction = "SetUser"
            xmlPacket = soapModifyUser
        case .create:
            funcAction = "CreateUsers"
            xmlPacket = soapCreateUser
        case .delete:
            funcAction = "DeleteUsers"
            xmlPacket = soapDeleteUser
        }
        
        let action = "http://www.onvif.org/ver10/device/wsdl/"+funcAction
        let apiUrl = URL(string: camera.xAddr)!
        
        var soapPacket = addAuthHeader(camera: camera, soapPacket: xmlPacket).replacingOccurrences(of: "\r", with: "")
        soapPacket = soapPacket.replacingOccurrences(of: "_USER_", with: user.name)
        soapPacket = soapPacket.replacingOccurrences(of: "_PWD_", with: user.pwd)
        soapPacket = soapPacket.replacingOccurrences(of: "_ROLE_", with: user.role)
        
        print(soapPacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
      
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                let errMsg = (error?.localizedDescription ?? "Connect error")
                print(errMsg)
               
                callback(camera,false,errMsg)
               
                return
            }else{
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    callback(camera,false,parser.authFault)
                    return
                }
                
                callback(camera,true,String(describing: adminAction))
                
            }
        }
        task.resume()
        
    }
    //MARK: Generic device_service GetXXXX func
    static func executeDeviceFunc(getFunc: String,camera: Camera,callback:@escaping (Camera,[String],Data?) -> Void){
        let onvif = OnvifDisco()
        onvif.prepare()
        onvif.getDeviceFunc(getFunc: getFunc, camera: camera, callback: callback)
    }
    func getStorageConfigurations(camera: Camera,callback:@escaping (Camera,[String],Data?) -> Void){
        getDeviceFunc(getFunc: "GetStorageConfigurations", camera: camera, callback: callback)
    }
    func getDeviceFunc(getFunc: String,camera: Camera,callback:@escaping (Camera,[String],Data?) -> Void){
        let action = "http://www.onvif.org/ver10/device/wsdl/"+getFunc
        
        let apiUrl = URL(string: camera.xAddr)!
        
        var soapPacket = addAuthHeader(camera: camera, soapPacket: soapDeviceFunc).replacingOccurrences(of: "\r", with: "")
        soapPacket = soapPacket.replacingOccurrences(of: "_FUNC_", with: getFunc)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
      
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                
                callback(camera,[String](),data)
                print(error?.localizedDescription ?? "No data")
                return
            }else{
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    callback(camera,[String](),data)
                    return
                }
                
                if let resp = String(data: data!, encoding: .utf8){
                    self.saveSoapPacket(endpoint: apiUrl, method: getFunc, xml: resp)
                
                
                    var keyValuePairs = [String:String]()
                    let xmlParser = XmlPathsParser(tag: ":"+getFunc+"Response")
                    xmlParser.parseRespose(xml: data!)
                    let xpaths = xmlParser.itemPaths
                    
                    callback(camera,xpaths,data)
                }else{
                    callback(camera,[],data)
                }
            }
        }
        task.resume()
    }
    func getDeviceInfo(camera: Camera,callback:@escaping (Camera) -> Void){
        
        let action = "http://www.onvif.org/ver10/device/wsdl/GetDeviceInformation";
        let apiUrl = URL(string: camera.xAddr)!
        
        let soapPacket = addAuthHeader(camera: camera, soapPacket: soapDeviceInfo).replacingOccurrences(of: "\r", with: "")
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        //let contentLen  = String(soapPacket.count)
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                callback(camera)
                camera.timeCheckOk = false
                print(error?.localizedDescription ?? "No data")
                if self.isAuthenticating{
                    self.authListener?.cameraAuthenticated(camera: camera, authenticated: false)
                }
                return
            }else{
                camera.timeCheckOk = true
                if let resp = String(data: data!, encoding: .utf8){
                    self.saveSoapPacket(endpoint: apiUrl, method: "device_info", xml: resp)
                }
                
                //check for :Fault
                //set camera.authFault =
                
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    camera.authenticated = false
                    camera.authFault = parser.authFault.trimmingCharacters(in: CharacterSet.whitespaces)
                    //self.saveSoapPacket(method: camera.name+"_device_info_err", xml: soapPacket)
                    
                }else{
                    CameraUpdater.updateDeviceInfo(camera: camera, data:data)
                    self.cameras.cameraUpdated(camera: camera)
                }
                callback(camera)
            }
            
        }
        
        task.resume()
    }
    //MARK: System Queries
    func getSystemLog(camera: Camera,logType: String,callback: @escaping(Camera,[String],String,Bool)->Void){
        var soapPacket = getXmlPacket(fileName: "soap_system_log")
        soapPacket = addAuthHeader(camera: camera, soapPacket: soapPacket)
        soapPacket = soapPacket.replacingOccurrences(of: "_LOG_TYPE_", with: logType)
        
        print(soapPacket)
        
        let action="http://www.onvif.org/ver10/device/wsdl/GetSystemLog"
        
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        let endpoint = URL(string: camera.xAddr)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                let errMsg = (error?.localizedDescription ?? "Connect error")
                callback(camera,[],errMsg,false)
                return
            }else{
                
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                    //print(resp)
                    callback(camera,[],fparser.authFault,false)
                    
                }else{
                    var results = [String]()
                    
                    let xmlParser = XmlPathsParser(tag: ":SystemLog")
                    xmlParser.parseRespose(xml: data!)
                    if xmlParser.itemPaths.count > 0{
                        let path = xmlParser.itemPaths[0].components(separatedBy: "/")
                        //print(path[1])
                        results = path[1].components(separatedBy: "\n")
                        
                        print("Onvif:systemLog line count",results.count)
                        
                    }
                    
                    callback(camera,results,"",true)
                    /*
                    if let resp = String(data: data!, encoding: .utf8){
                        self.saveSoapPacket(endpoint: endpoint, method: logType + "_log", xml: resp)
                    }
                     */
                }
                
                
            }
        }
        task.resume()
    }
    func rebootDevice(camera: Camera,callback: @escaping (Camera,[String],Data?)->Void){
        getDeviceFunc(getFunc: "SystemReboot", camera: camera,callback: callback)
    }
    func getSystemCapabilites(camera: Camera,callback: @escaping (Camera,[String],Data?)->Void){
        getDeviceFunc(getFunc: "GetServiceCapabilities", camera: camera,callback: callback)
    }
    func doExtraQueries(camera: Camera){
        getDeviceFunc(getFunc: "GetNetworkInterfaces", camera: camera,callback: handleGetNetworkInterfaces)
    }
    func handleGetNetworkInterfaces(camera: Camera,xPaths: [String],data: Data?){
        
        CameraUpdater.updateNetworkInterfaces(camera: camera, data: data)
    }
    //MARK: Save XML
    func saveSoapPacket(endpoint: URL, method: String,xml: String){
       
        if let host = endpoint.host{
            var port = "80"
            if endpoint.port != nil{
                port = String(endpoint.port!)
            }
            let filename = host + "_" + port + "_" + method+".xml"
            let pathComponent = FileHelper.getPathForFilename(name: filename)
            
            do {
                try xml.write(to: pathComponent, atomically: true, encoding: String.Encoding.utf8)
            } catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
                print("FAILED TO SAVE",pathComponent.path)
            }
        }
        //return pathComponent
    }
}

class SystemTimeParser : NSObject, XMLParserDelegate{
    
    let keys = ["Year", "Month", "Day", "Hour", "Minute", "Second"]
    var vals = ["","","","","",""]
    
    var sysDateTime = Date()
    var currentStr = ""
    var isCollecting  = false;
    var currentIndex = -1
    var hasDateTime = false
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        for i in 0...keys.count-1{
            if elementName.contains(":"+keys[i]){
                currentIndex = i
                currentStr = ""
                isCollecting = true;
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            if(string.contains(":")==false){
                currentStr += string
            }
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
           
            vals[currentIndex] = currentStr
            currentIndex = -1
            currentStr = ""
            isCollecting = false
        }
    }
    func parserDidEndDocument(_ parser: XMLParser) {
    
        //create date and assign to camera
        var components = DateComponents()
        components.year = Int(vals[0])
        components.month = Int(vals[1])
        components.day = Int(vals[2])
        components.hour = Int(vals[3])
        components.minute = Int(vals[4])
        components.second = Int(vals[5])
        
        sysDateTime = Calendar.current.date(from: components)!
        hasDateTime = vals[1].isEmpty == false
    }
}
class FaultParser : NSObject,XMLParserDelegate{
    
    var authFault = ""
    var authFaults = [String]()
    
    let faultTag = ":Fault"
    let faultValue = ":Value"
    let faultReason = ":Reason"
    let altFaultTag = ":faultstring"
    
    func hasFault() -> Bool{
        return authFaults.count>0
    }
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    var currentStr = ""
    var isCollecting  = false;
    var tagFound = false
    private var faultFound = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        // print(elementName);
        
        if(elementName.contains(self.faultTag) || elementName.contains(altFaultTag)){
            faultFound = true
            isCollecting = true
            
        }
        if(tagFound == false && faultFound && elementName.contains(self.faultValue)){
            tagFound = true
            isCollecting = true;
        }
        if(tagFound && faultFound && elementName.contains(self.faultReason)){
            tagFound = true
            isCollecting = true;
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            if(string.contains(":")==false){
                currentStr += string
            }
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            
            if(faultFound && currentStr.isEmpty == false){
                self.authFault += " "+self.currentStr
                authFaults.append(currentStr)
                faultFound = false
            }
            self.currentStr = ""
            isCollecting = false
        }
    }
}
class MultiTagParser : NSObject, XMLParserDelegate{
    var keys: [String]
    var vals: [String]
    
    init(keys: [String]){
        self.keys = keys
        self.vals = [String]()
        for i in 0...keys.count-1 {
            vals.append("")
        }
    }
    
    var currentStr = ""
    var isCollecting  = false;
    var currentIndex = -1
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        for i in 0...keys.count-1{
            if elementName.contains(":"+keys[i]){
                currentIndex = i
                currentStr = ""
                isCollecting = true;
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            if(string.contains(":")==false){
                currentStr += string
            }
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
           
            vals[currentIndex] = currentStr
            currentIndex = -1
            currentStr = ""
            isCollecting = false
        }
    }
}
class SingleTagParser : NSObject, XMLParserDelegate{
    
    var tagToFind: String
    var result: String = ""
    
    init(tagToFind: String){
        self.tagToFind = tagToFind
    }
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    var currentStr = ""
    var isCollecting  = false;
    var tagFound = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        if result.isEmpty {
        
            if(elementName.contains(self.tagToFind)){
                tagFound = true
                isCollecting=true
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            result = currentStr
            isCollecting = false
        }
    }
}
class XAddrParser : NSObject, XMLParserDelegate{
    
    var tagToFind: String
    var xAddr: String = ""
    var serviceXAddr: String = ""
    
    init(tagToFind: String,serviceXAddr: String){
        self.tagToFind = tagToFind
        self.serviceXAddr = serviceXAddr
    }
    
    func parseRespose(xml: Data){
        let parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    
    var currentStr = ""
    var isCollecting  = false;
    var tagFound = false
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        
        // print(elementName);
        if xAddr.count > 0 {
            return;
            
        }
        if(elementName.contains(":"+self.tagToFind)){
            tagFound = true
        }
        if(tagFound && elementName.contains("XAddr")){
            isCollecting=true
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            if let ipa = URL(string: currentStr){
                if let xmlIpa = ipa.host{
                    var serviceIpa = self.serviceXAddr
                    if serviceIpa.hasPrefix("http"){
                        serviceIpa = URL(string: self.serviceXAddr)!.host!
                    }
                    if(xmlIpa != serviceIpa){
                        print("XAddrParser updating IP",xmlIpa,serviceIpa)
                        xAddr = currentStr.replacingOccurrences(of: xmlIpa, with: serviceIpa)
                        
                    }else{
                        xAddr = currentStr
                    }
          
                //port morphing for example 80 to 8080 in disco WAN address
                if xAddr.hasPrefix("http") && serviceIpa.hasPrefix("http"){
                    if let xUrl = URL(string: xAddr){
                        if let xServiceUrl = URL(string: self.serviceXAddr){
                            if xUrl.port != xServiceUrl.port{
                                print("Onvif: correcting WAN port from",xUrl.port,xServiceUrl.port)
                                xAddr = xAddr.replacingOccurrences(of: String(xUrl.port!), with: String(xServiceUrl.port!));
                            }
                        }
                    }
                    
                }
              
                isCollecting = false
                }
            }
        }
    }
}

class DiscoveryParser : NSObject, XMLParserDelegate{
    var camName = ""
    var xAddr = ""
    var urn = ""
    
    func parseRespose(xml: Data){
        
        tags.append(scopesTag)
        tags.append(xAddrTag)
        
        var parser = XMLParser(data: xml)
        parser.delegate = self
        parser.parse()
    }
    func parserDidStartDocument(_ parser: XMLParser) {
        print("Start of DOC")
    }
    func parserDidEndDocument(_ parser: XMLParser) {
        print("End of doc");
    }
    var currentStr = ""
    var isCollecting  = false;
    var currentType = "";
    var scopesTag = "Scopes"
    var xAddrTag = "XAddrs"
    var tags = [String]()
    
    var endpointTag = ":EndpointReference"
    var isEndpointTag = false
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        if elementName.hasSuffix(endpointTag){
            isEndpointTag = true
            
        }
        
        if isEndpointTag && elementName.hasSuffix(":Address"){
            currentStr = ""
            isCollecting = true
        }else{
            for i in 0...tags.count-1{
                if(elementName.contains(":"+tags[i])){
                    //print(elementName)
                    currentStr = ""
                    currentType = tags[i]
                    self.isCollecting = true
                }
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if(isCollecting){
            currentStr += string
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        
        if(isCollecting){
            
            isCollecting = false
            if isEndpointTag{
                urn = currentStr
                isEndpointTag = false
            }
            
            else if(currentType == scopesTag){
                //extract Name/hardware etc
                //print("Scopes",currentStr)
                let scopes = currentStr.components(separatedBy: " ")
                print("nScopes="+String(scopes.count))
                
                for i in 0...scopes.count-1{
                    let scope = scopes[i]
                    if scope.contains("/name/"){
                        //print("Name ",scope)
                        let parts = scope.components(separatedBy: "/")
                        self.camName = parts[parts.count-1];
                        print("Name",self.camName)
                    }
                }
                
            }else if(currentType == xAddrTag){
                //print("xAddr=",currentStr)
                let addrs = currentStr.components(separatedBy: " ")
                self.xAddr = addrs[0]
                print("xAddr=", self.xAddr)
                
            }
            
        }
    }
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
    }
}
