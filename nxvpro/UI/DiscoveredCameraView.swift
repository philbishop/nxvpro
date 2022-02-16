//
//  DiscoveredCameraView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 19/06/2021.
//

import SwiftUI

class CameraModel: ObservableObject {
    @Published var cameraName: String = ""
    @Published var cameraInfo: String = ""
    @Published var cameraAddr: String = ""
    @Published var cameraRes: [String] = [String]()
    @Published var selectedRs: String = ""
    @Published var isAuthenticated: Bool = false
    @Published var ctrlDisabled: Bool = true
    @Published var ctlsDisabled: Bool = true
    @Published var thumb: UIImage?
    @Published var isFav: Bool = false
    @Published var favIcon: String
    @Published var rotation: Double = 0.0
    @Published var loginStatus: String = ""
    @Published var cUser: String = ""
    @Published var cPwd: String = ""
    @Published var selected: Bool = false
    @Published var isZombie: Bool = false
    @Published var isNvr: Bool = false
    
    var camera: Camera
    
    init(camera: Camera){
        self.camera  = camera
        self.thumb = UIImage(contentsOfFile: camera.thumbPath())
        self.favIcon = "fav_light"
        self.rotation = Double(camera.rotationAngle)
        
        cameraUpdated()
    }
    
    func toggleFav(){
        camera.isFavorite = !camera.isFavorite
        isFav = self.camera.isFavorite
    }
    
    func updateCameraProfile(){
        camera.setSelectedProfile(res: selectedRs)
    }
    func cameraUpdated(){
        self.cameraName = camera.getDisplayName()
        self.cameraInfo = camera.getInfo()
        self.cameraAddr = camera.getDisplayAddr()
        if self.cameraAddr.count > 16{
            self.cameraAddr = Helpers.truncateString(inStr: camera.getDisplayAddr(), length: 16)
        }
        self.cameraRes = [String]()
        self.isAuthenticated = camera.isAuthenticated()
        self.isFav = camera.isFavorite
        self.rotation = Double(camera.rotationAngle)
        self.isNvr = camera.isNvr()
        
        
        let useToken = camera.hasDuplicateResolutions()
        
        if self.isAuthenticated && self.camera.profiles.count > 0 {
            for i in 0...camera.profiles.count-1 {
                self.cameraRes.append(self.camera.profiles[i].getDisplayResolution(useToken: useToken))
            }
            
            if self.selectedRs.isEmpty {
                let pi = camera.profileIndex != -1 ? camera.profileIndex : 0
                self.selectedRs = self.camera.profiles[pi].getDisplayResolution(useToken: useToken)
            }
        }
        
        //self.selectedRs = self.camera.getDisplayResolution()
        self.loginStatus = camera.name
        
        if self.isNvr{
            print("CameraModel:cameraUpdated NVR",self.cameraAddr,self.isAuthenticated)
            let nvrPlaceholderIcon: String = "nxv_nvr_icon_gray_thumb"
            self.thumb = UIImage(named: nvrPlaceholderIcon)
        }else{
            print("CameraModel:cameraUpdated",self.cameraAddr,self.isAuthenticated)
        }
        
        
    }
    
    func updateSelectedProfile(saveChanges: Bool = false){
        if self.camera.profiles.count > 0 {
            for i in 0...camera.profiles.count-1 {
                //if camera.profiles[i].getDisplayResolution(useToken: isNvr) == selectedRs {
                if camera.profiles[i].isSameProfile(selectedRs: selectedRs){
                    camera.profileIndex = i
                    if saveChanges{
                        camera.save()
                    }
                    break;
                }
            }
        }
    }
}

struct DiscoveredCameraView: View, AuthenicationListener, CameraChanged {
    
    func setZombieState(isZombie: Bool){
        viewModel.isZombie = isZombie
    }
    
    func onCameraChanged() {
        AppLog.write("DiscoveredCameraView:onCameraChanged",camera.getDisplayAddr())
        DispatchQueue.main.async {
            if camera.profiles.count > 0 {
                viewModel.isAuthenticated = camera.isAuthenticated()
                viewModel.selectedRs = camera.getDisplayResolution()
                //AppLog.write("DiscoveredCameraView:selectedRs",viewModel.selectedRs)
                viewModel.cameraName = camera.getDisplayName()
                //AppLog.write("DiscoveredCameraView:displayName",viewModel.cameraName)
                setZombieState(isZombie: camera.isZombie)
                
            }
           
        }
    }
    func thumbChanged(){
        AppLog.write("DiscoverCamera:Model thumb updated",camera.getDisplayAddr())
        viewModel.thumb  = UIImage(contentsOfFile: camera.thumbPath())
    }
    func cameraAuthenticated(camera: Camera, authenticated: Bool) {
        AppLog.write("DiscoveredCameraView:cameraAuthenticated",camera.getDisplayAddr(),authenticated)
        DispatchQueue.main.async {
            viewModel.camera = camera
            viewModel.cameraUpdated()
            
            if authenticated {
                camera.save()
                
            }
            else{
                viewModel.loginStatus = "Auth failed"
            }
        }
    }
    
    
    var camera: Camera
    @ObservedObject var viewModel: CameraModel
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    init(camera: Camera){
        self.camera = camera
        //don't overrwite existing profiles
        //self.camera.profiles = [CameraProfile]()
       
        self.viewModel = CameraModel(camera: self.camera)
        //listener moved to Factory to delegate to both lists of cameras
        //self.camera.setListener(listener: self)
        
        AppLog.write("DiscoverCameraUIView;init",camera.getDisplayAddr(),camera.isAuthenticated())
        
        
    }
    var iconSize = CGFloat(24)
    @State var ctrlsOpacity: Double = 1
    @State var rowHeight = DiscoCameraViewFactory.tileHeight
    @State var rowWidth = DiscoCameraViewFactory.tileWidth + 30
    
   
    var body: some View {
        let thumbH = rowHeight - 20
        let thumbW = thumbH * 1.6
        let ctrlWidth = rowWidth - thumbW
        ZStack(alignment: .bottomTrailing) {
            HStack(spacing: 15){
                   //thumb
                Image(uiImage: viewModel.thumb!).resizable().frame(width: thumbW, height: thumbH, alignment: .center)
                    .cornerRadius(5).rotationEffect(Angle(degrees: viewModel.rotation)).clipped()
               
                    ZStack(alignment: .leading){
                       VStack(alignment: .leading,spacing: 4){
                           Text(viewModel.cameraName).fontWeight(.semibold).appFont(.body)
                            .frame(width: ctrlWidth,alignment: .leading).lineLimit(1)
           
                       if viewModel.isAuthenticated{
                           if viewModel.isNvr{
                               Text("Group created").appFont(.body).frame(alignment: .leading)
                           }else{
                               Text(self.viewModel.selectedRs).appFont(.body).frame(alignment: .leading)
                           }
                       }else{
                           Text("Login required").foregroundColor(.accentColor).appFont(.caption).frame(alignment: .leading)
                       }
                        HStack{
                            Text(self.viewModel.cameraAddr)
                                .appFont(.caption)
                                .lineLimit(1)
                                .frame(alignment: .leading)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable().frame(width: 18,height: 18,alignment: .trailing)
                                .foregroundColor(.orange)
                                .hidden(viewModel.isZombie==false)
                        }
                        
                       }.frame(alignment: .leading)
                       
                    }.padding(0)
                
                }
            
        }
        .frame(width: rowWidth,height: rowHeight,alignment: .leading)
            .onAppear(){
                viewModel.loginStatus = camera.name
                iconModel.initIcons(isDark: colorScheme == .dark )
                //thumbChanged()
           }
    }
    
    func doAuth(){
        
        if viewModel.cUser.isEmpty {
            return
        }
        viewModel.camera.user = viewModel.cUser
        viewModel.camera.password = viewModel.cPwd
        viewModel.loginStatus =  "authenticating..."
        let onvifAuth = OnvifDisco()
        onvifAuth.startAuthorized(camera: viewModel.camera, authListener: self)
    }
   
}

class CameraChangedDelegate : CameraChanged {
    var camera: Camera
    
    init(camera: Camera){
        self.camera = camera
    }
    func onCameraChanged() {
        print("CameraChangeDelegate:onChange",camera.getDisplayAddr())
        DiscoCameraViewFactory.handleCameraChange(camera: camera)
    }
    
    
}
class DiscoCameraViewFactory{
    static var tileWidth = CGFloat(230)
    static var tileHeight = CGFloat(65)
    
    static var views = [DiscoveredCameraView]()
    static var views2 = [DiscoveredCameraView]()
    static var changeListeners = [String: CameraChangedDelegate]()
    
    static func reset(){
        views = [DiscoveredCameraView]()
        views2 = [DiscoveredCameraView]()
        changeListeners = [String: CameraChangedDelegate]()
    }
    
    static func handleCameraChange(camera: Camera){
        for dcv in views {
            if dcv.camera.xAddrId == camera.xAddrId {
                dcv.onCameraChanged()
                break;
            }
        }
        for dcv in views2 {
            if dcv.camera.xAddrId == camera.xAddrId {
                dcv.onCameraChanged()
                break;
            }
        }
    }
    
    static func getInstance(camera: Camera) -> DiscoveredCameraView{
        let chd = CameraChangedDelegate(camera: camera)
        changeListeners[camera.xAddrId] = chd
        
        camera.setListener(listener: chd)
        
        if views.count > 0 {
            for i in 0...views.count-1 {
                if( views[i].camera.xAddrId == camera.xAddrId){
                    return views[i]
                }
            }
        }
        let nv = DiscoveredCameraView(camera: camera)
        nv.rowWidth = tileWidth
        views.append(nv)
        
        return nv
    }

    static func deselectAll(){
        if views.count > 0 {
            for i in 0...views.count-1 {
                views[i].viewModel.selected = false
            }
        }
    }
    static func moveView2(fromOffsets source: IndexSet, toOffsets destination: Int) -> [Camera]{
        views2.move(fromOffsets: source, toOffset: destination)
        var cams = [Camera]()
        for view in views2{
            cams.append(view.camera)
        }
        return cams
    }
    static func getInstance2(camera: Camera) -> DiscoveredCameraView{
        
        if views2.count > 0 {
            for i in 0...views2.count-1 {
                if( views2[i].camera.xAddrId == camera.xAddrId){
                    views2[i].camera.orderListener?.onCameraChanged()
                    return views2[i]
                }
            }
        }
        let nv = DiscoveredCameraView(camera: camera)
        nv.rowWidth = tileWidth
        views2.append(nv)
        
        return nv
    }
    
}

/*
struct DiscoveredCameraView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoveredCameraView()
    }
}
 */
