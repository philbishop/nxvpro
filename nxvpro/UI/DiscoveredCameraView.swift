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
    //@Published var ctrlDisabled: Bool = true
    //@Published var ctlsDisabled: Bool = true
    @Published var thumbVisible = true
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
    
    @Published var isSelected: Bool = false
    
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
        camera.save()
        camera.flagChanged()
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
        self.loginStatus = camera.getDisplayName()
        
        print("CameraModel:cameraUpdated",self.cameraAddr,self.isAuthenticated)
        changeIconIfNvr()
        
        
    }
    func changeIconIfNvr(){
        if self.isNvr{
            print("CameraModel:cameraUpdated NVR",self.cameraAddr,self.isAuthenticated)
            let nvrPlaceholderIcon: String = "nxv_nvr_icon_gray_thumb"
            self.thumb = UIImage(named: nvrPlaceholderIcon)
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
                    globalCameraEventListener?.onCameraSelected(camera: camera, isMulticamView: false)
                    break;
                }
            }
        }
    }
}

struct DiscoveredCameraView: View, AuthenicationListener, CameraChanged {
    //Camera Changed, not used in this context
    func getSrc() -> String {
        return viewModel.cameraAddr
    }
    
    
    func setZombieState(isZombie: Bool){
        viewModel.isZombie = isZombie
    }
    func toggleAndUpdateFavIcon() -> Bool{
        viewModel.toggleFav()
        updateFavIcon()
        //globalToolbarListener?.onFavStatusChanged()
        return viewModel.isFav
    }
    func updateFavIcon(){
        if viewModel.isFav {
            viewModel.favIcon = iconModel.activeFavIcon
        }else{
            viewModel.favIcon = iconModel.favIcon
        }
    }
    func onCameraChanged() {
       
        AppLog.write("DiscoveredCameraView:onCameraChanged",camera.getDisplayAddr())
        DispatchQueue.main.async {
            viewModel.isAuthenticated = camera.isAuthenticated()
            viewModel.cameraName = camera.getDisplayName()
            viewModel.isNvr = camera.isNvr()
            viewModel.changeIconIfNvr()
            if camera.profiles.count > 0 {
                
                viewModel.selectedRs = camera.getDisplayResolution()
                //AppLog.write("DiscoveredCameraView:selectedRs",viewModel.selectedRs)
                
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
        
        self.viewModel = CameraModel(camera: camera)
       
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
            HStack(spacing: 10){
                if viewModel.thumbVisible{
                    Image(uiImage: viewModel.thumb!).resizable().frame(width: thumbW, height: thumbH, alignment: .center)
                        .cornerRadius(5).rotationEffect(Angle(degrees: viewModel.rotation)).clipped()
                }
                    ZStack(alignment: .leading){
                       VStack(alignment: .leading,spacing: 4){
                           Text(viewModel.cameraName).fontWeight(.semibold).appFont(.body)
                            .frame(width: ctrlWidth,alignment: .leading).lineLimit(1)
           
                       if viewModel.isAuthenticated{
                           if viewModel.isNvr{
                               Text("Group created").appFont(.body)
                                   
                                   .frame(alignment: .leading)
                           }else{
                               HStack{
                                   if viewModel.isSelected{
                                      
                                       Picker("", selection: $viewModel.selectedRs) {
                                           ForEach(self.viewModel.cameraRes, id: \.self) {
                                               Text($0).lineLimit(1)
                                                   
                                           }
                                       }.onChange(of: viewModel.selectedRs) { newRes in
                                           print("DiscoveredCameraView:Profile changed",newRes,viewModel.camera.getDisplayName())
                                           viewModel.updateSelectedProfile()
                                           
                                       }.pickerStyle(.menu).onTapGesture {
                                           print("DiscoveredCameraView:Profile tapped");
                                       }.frame(width: 90,alignment: .leading)
                                   }else{
                                       Text(self.viewModel.selectedRs).appFont(.body).frame(width: 90,alignment: .leading)
                                   }
                                   Image(viewModel.isFav ? iconModel.activeFavIcon : iconModel.favIcon).resizable()
                                       //.padding(.leading)
                                       .frame(width: 24,height: 24)
                                       .onTapGesture {
                                           camera.isFavorite = !camera.isFavorite
                                           viewModel.isFav = camera.isFavorite
                                           camera.save()
                                           
                                       }.padding(.leading)
                                      
                               }.frame(width: ctrlWidth,alignment: .leading)
                           }
                       }else{
                           Text("Login required").foregroundColor(.accentColor).appFont(.caption).frame(alignment: .leading)
                       }
                        HStack{
                            Text(self.viewModel.cameraAddr)
                                .appFont(.caption)
                                .lineLimit(1)
                                .frame(width: ctrlWidth - 18,alignment: .leading)
                            
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable().frame(width: 18,height: 18)
                                .foregroundColor(.orange)
                                .hidden(viewModel.isZombie==false)
                        }
                        
                       }.frame(alignment: .leading)
                       
                    }.padding(0)
                
            }.padding(0)
                .frame(alignment: .leading)
        }
        .frame(height: rowHeight,alignment: .leading)
            .onAppear(){
                viewModel.loginStatus = camera.getDisplayName()
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
    
    func getSrc() -> String {
        return camera.xAddr
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
    static var otherListeners = [CameraChanged]()
    
    static func addListener(listener: CameraChanged){
        for ccl in otherListeners{
            if ccl.getSrc() == listener.getSrc(){
                print("DiscoCameraViewFactory:addListener exists",ccl.getSrc())
                return
            }
        }
        otherListeners.append(listener)
    }
    
    static func reset(){
        views = [DiscoveredCameraView]()
        views2 = [DiscoveredCameraView]()
        changeListeners = [String: CameraChangedDelegate]()
    }
    
    static func makeThumbVisible(viz: Bool){
        for dcv in views {
            dcv.viewModel.thumbVisible = viz
        }
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
        for ccl in otherListeners{
            ccl.onCameraChanged()
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
    static func setCameraSelected(camera: Camera){
        setCameraSelectedImp(camera: camera, viewsToUse: views)
        setCameraSelectedImp(camera: camera, viewsToUse: views2)
        /*
        if views.count > 0 {
            for i in 0...views.count-1 {
                var isSelected = false
                if views[i].camera.sameAs(camera: camera){
                    isSelected = true
                }
                views[i].viewModel.isSelected = isSelected
            }
        }
         */
    }
    private static func setCameraSelectedImp(camera: Camera,viewsToUse: [DiscoveredCameraView]){
        if viewsToUse.count > 0 {
           for i in 0...viewsToUse.count-1 {
               var isSelected = false
               if viewsToUse[i].camera.sameAs(camera: camera){
                   isSelected = true
               }
               viewsToUse[i].viewModel.isSelected = isSelected
           }
       }
    }
    static func moveView(fromOffsets source: IndexSet, toOffsets destination: Int) -> [Camera]{
        
        views.move(fromOffsets: source, toOffset: destination)
        var cams = [Camera]()
        var orderId = 0
        for view in views{
            
            if view.camera.isVirtual == false{
                view.camera.displayOrder = orderId
                cams.append(view.camera)
                
                print("moveView",view.camera.getStringUid(),view.camera.getDisplayName(),orderId)
                
                orderId += 1
            }
        }
        return cams
    }
    
    static func getInstance2(camera: Camera) -> DiscoveredCameraView{
        let chd = CameraChangedDelegate(camera: camera)
        changeListeners[camera.xAddrId] = chd
        
        camera.setListener(listener: chd)
        
        if views2.count > 0 {
            for i in 0...views2.count-1 {
                if( views2[i].camera.xAddrId == camera.xAddrId){
                    //views2[i].camera.orderListener?.onCameraChanged()
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
