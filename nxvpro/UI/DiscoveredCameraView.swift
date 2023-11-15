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
    @Published var profilePickerEnabled = false
    
    @Published var isNetStream = false
    
    @Published var moveMode = false
    
    var isIosOnMac = false
    var camera: Camera
    
    init(camera: Camera){
        self.camera  = camera
        self.thumb = UIImage(contentsOfFile: camera.thumbPath())
        self.favIcon = "fav_light"
        self.rotation = Double(camera.rotationAngle)
        self.isNetStream = camera.isNetworkStream()
        
        if ProcessInfo.processInfo.isiOSAppOnMac{
            isIosOnMac = true
        }
        
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
        self.selectedRs = ""
        
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
        
        AppLog.write("CameraModel:cameraUpdated",self.cameraAddr,self.isAuthenticated)
        changeIconIfNvr()
   
    }
    func changeIconIfNvr(){
        if self.isNvr{
            AppLog.write("CameraModel:cameraUpdated NVR",self.cameraAddr,self.isAuthenticated)
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
                    globalCameraEventListener?.onCameraSelected(camera: camera, isCameraTap: false)
                    break;
                }
            }
        }
    }
    func getFont4Res() -> Font{
        var fs = 16.0
        let len = selectedRs.count
        if len > 13{
            fs = 12
        }else if len > 9{
            fs = 14
        }
        return Font.system(size: fs)
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
       
        AppLog.write("DiscoveredCameraView:onCameraChanged",camera.getDisplayAddr(),camera.isAuthenticated())
        DispatchQueue.main.async {
            viewModel.isAuthenticated = camera.isAuthenticated()
            viewModel.cameraName = camera.getDisplayName()
            viewModel.isNvr = camera.isNvr()
            viewModel.isFav = camera.isFavorite
            viewModel.changeIconIfNvr()
            if camera.profiles.count > 0 {
                let useToken = camera.hasDuplicateResolutions()
                viewModel.selectedRs = camera.getDisplayResolution(useToken)
                //AppLog.write("DiscoveredCameraView:selectedRs",viewModel.selectedRs)
                
                //AppLog.write("DiscoveredCameraView:displayName",viewModel.cameraName)
                setZombieState(isZombie: camera.isZombie)
                
            }else if camera.isNetworkStream(){
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
    func setMoveMode(on:Bool){
        viewModel.moveMode = on
    }
    var iconSize = CGFloat(24)
    @State var ctrlsOpacity: Double = 1
    @State var rowHeight = DiscoCameraViewFactory.tileHeight
    @State var rowWidth = DiscoCameraViewFactory.tileWidth // + 30
    
    
    var body: some View {
        let thumbH = rowHeight - 25
        let thumbW = thumbH * 1.6
        let ctrlWidth = rowWidth - thumbW
        
        ZStack(alignment: .leading) {
            
            HStack(spacing: 10){
                if viewModel.thumbVisible{
                    Image(uiImage: viewModel.thumb!).resizable().frame(width: thumbW, height: thumbH, alignment: .center)
                        .cornerRadius(5).rotationEffect(Angle(degrees: viewModel.rotation))
                        .padding(0)
                        .clipped()
                }
                    ZStack(alignment: .leading){
                       VStack(alignment: .leading,spacing: 4){
                           Text(viewModel.cameraName).fontWeight(.semibold).appFont(.body)
                            .frame(width: ctrlWidth,alignment: .leading).lineLimit(1)
           
                       if viewModel.isAuthenticated{
                           if viewModel.isNvr{
                               Text("Group created").appFont(.body)
                                   .scaledToFill()
                                   .minimumScaleFactor(0.5)
                                   .lineLimit(1)
                                   .frame(alignment: .leading)
                           }else{
                               HStack{
                                   if viewModel.isNetStream{
                                       Text("Network stream").appFont(.footnote)
                                           .frame(width: 90,alignment: .leading)
                                   }else if viewModel.isSelected && viewModel.profilePickerEnabled{
                                      
                                       Picker("", selection: $viewModel.selectedRs) {
                                           ForEach(self.viewModel.cameraRes, id: \.self) {
                                               Text($0).lineLimit(nil)
                                                   
                                           }
                                       }.onChange(of: viewModel.selectedRs) { newRes in
                                           AppLog.write("DiscoveredCameraView:Profile changed",newRes,viewModel.camera.getDisplayName())
                                           viewModel.updateSelectedProfile()
                                           
                                           viewModel.profilePickerEnabled = false
                                           
                                       }.pickerStyle(.menu)
                                           .frame(alignment: .leading)
                                           .clipped()
                                           
                                   }else{
                                       
                                       Text(self.viewModel.selectedRs).font(viewModel.getFont4Res())
                                           .frame(width: 90,alignment: .leading)
                                           .onTapGesture {
                                               if viewModel.isSelected{
                                                   viewModel.profilePickerEnabled = true
                                               }else{
                                                   globalCameraEventListener?.onCameraSelected(camera: camera, isCameraTap: false)
                                               }
                                           }
                                   }
                                   if viewModel.moveMode==false{
                                       Image(viewModel.isFav ? iconModel.activeFavIcon : iconModel.favIcon).resizable()
                                       //.padding(.leading)
                                           .frame(width: 24,height: 24)
                                           .onTapGesture {
                                               camera.isFavorite = !camera.isFavorite
                                               viewModel.isFav = camera.isFavorite
                                               camera.save()
                                               
                                           }.padding(.leading)
                                           .hidden(viewModel.profilePickerEnabled)
                                   }
                               }
                           }
                       }else{
                           Text("Login required").foregroundColor(.accentColor).appFont(.caption).frame(alignment: .leading)
                       }
                        HStack{
                            Text(self.viewModel.cameraAddr)
                                .appFont(.caption)
                                .lineLimit(1)
                                .frame(width: 110,alignment: .leading)
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .resizable().frame(width: 18,height: 18)
                                .foregroundColor(.orange)
                                .hidden(viewModel.isZombie==false)
                        }
                        
                       }
                       .padding(.trailing,3)
                       .frame(alignment: .leading)
                       
                    }.padding(0)
                
            }.padding(0)
                .frame(alignment: .leading)
        }
        
        .frame(width: ctrlWidth, height: rowHeight,alignment: .leading)
            .onAppear(){
               
                viewModel.loginStatus = camera.getDisplayName()
                iconModel.initIcons(isDark: colorScheme == .dark )
                
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
        onvifAuth.startAuthorized(camera: viewModel.camera, authListener: self,src: "DiscoveredCameraView")
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
      
        AppLog.write("CameraChangeDelegate:onChange",camera.getDisplayAddr())
        DiscoCameraViewFactory.handleCameraChange(camera: camera)
    }
    
    
}
class DiscoCameraViewFactory{
    static var tileWidth = CGFloat(230)
    static var tileHeight = CGFloat(65)
    
    static var views = [DiscoveredCameraView]()
    static var views2 = [DiscoveredCameraView]()
    static var views3 = [DiscoveredCameraView]()
    static var changeListeners = [String: CameraChangedDelegate]()
    static var otherListeners = [CameraChanged]()
    
    static func addListener(listener: CameraChanged){
        for ccl in otherListeners{
            if ccl.getSrc() == listener.getSrc(){
                AppLog.write("DiscoCameraViewFactory:addListener exists",ccl.getSrc())
                return
            }
        }
        otherListeners.append(listener)
    }
    
    static func reset(){
        views = [DiscoveredCameraView]()
        views2 = [DiscoveredCameraView]()
        views3 = [DiscoveredCameraView]()
        changeListeners = [String: CameraChangedDelegate]()
    }
    //MARK: iOS 17 List move mode
    static func setMoveMode(on: Bool){
        for dcv in views {
            dcv.setMoveMode(on: on)
        }
        for dcv in views2 {
            dcv.setMoveMode(on: on)
        }
        for dcv in views3 {
            dcv.setMoveMode(on: on)
        }
    }
    static func makeThumbVisible(viz: Bool){
        for dcv in views {
            //if dcv.camera.isNvr(){
                dcv.viewModel.thumbVisible = viz
            //}
        }
        for dcv in views2 {
           // if dcv.camera.isNvr(){
                dcv.viewModel.thumbVisible = viz
           // }
        }
        for dcv in views3 {
           // if dcv.camera.isNvr(){
                dcv.viewModel.thumbVisible = viz
          //  }
        }
    }
    static func handleThumbChanged(_ camera: Camera){
        for dcv in views {
            if dcv.camera.sameAs(camera: camera) {
                dcv.thumbChanged()
            }
        }
        for dcv in views2 {
            if dcv.camera.sameAs(camera: camera) {
                dcv.thumbChanged()
            }
        }
        for dcv in views3 {
            if dcv.camera.sameAs(camera: camera) {
                dcv.thumbChanged()
            }
        }
    }
    static func handleCameraChange(camera: Camera,isAuthChange: Bool = false){
        for dcv in views {
            if dcv.camera.sameAs(camera: camera) {
                if isAuthChange{
                    dcv.cameraAuthenticated(camera: camera, authenticated: true)
                }else{
                    dcv.onCameraChanged()
                    let cam = dcv.camera
                    if cam.isNvr() && cam.isAuthenticated(){
                        for vcam in cam.vcams{
                            handleCameraChange(camera: vcam, isAuthChange: false)
                        }
                    }
                }
                break;
            }
        }
        for dcv in views2 {
            if dcv.camera.sameAs(camera: camera) {
                if isAuthChange{
                    dcv.cameraAuthenticated(camera: camera, authenticated: true)
                }else{
                    dcv.onCameraChanged()
                    let cam = dcv.camera
                    if cam.isNvr() && cam.isAuthenticated(){
                        for vcam in cam.vcams{
                            handleCameraChange(camera: vcam, isAuthChange: false)
                        }
                    }
                }
                break;
            }
        }
        for dcv in views3 {
            if dcv.camera.sameAs(camera: camera) {
                if isAuthChange{
                    dcv.cameraAuthenticated(camera: camera, authenticated: true)
                }else{
                    dcv.onCameraChanged()
                    let cam = dcv.camera
                    if cam.isNvr() && cam.isAuthenticated(){
                        for vcam in cam.vcams{
                            handleCameraChange(camera: vcam, isAuthChange: false)
                        }
                    }
                }
                break;
            }
        }
        for ccl in otherListeners{
            ccl.onCameraChanged()
        }
    }
    
    static func getInstanceView(camera: Camera,viewId: Int) -> DiscoveredCameraView{
        if viewId == 1{
            return getInstanceFor(camera: camera, theViews: &views)
            //return getInstance(camera: camera)
        }else if viewId == 2{
            return getInstanceFor(camera: camera, theViews: &views2)
        }else{
            return getInstanceFor(camera: camera, theViews: &views3)
        }
        //return getInstance2(camera: camera)
    }
    private static func getInstanceFor(camera: Camera, theViews: inout [DiscoveredCameraView]) -> DiscoveredCameraView{
        let chd = CameraChangedDelegate(camera: camera)
        changeListeners[camera.xAddrId] = chd
        
        camera.setListener(listener: chd)
        
        if theViews.count > 0 {
            for i in 0...theViews.count-1 {
                if( theViews[i].camera.xAddrId == camera.xAddrId){
                    return theViews[i]
                }
            }
        }
        FileHelper.migrateJpgThumb2Png(camera: camera)
        let nv = DiscoveredCameraView(camera: camera)
        nv.rowWidth = tileWidth
        theViews.append(nv)
        
        return nv
    }

    /*
    static func deselectAll(){
        if views.count > 0 {
            for i in 0...views.count-1 {
                views[i].viewModel.selected = false
            }
        }
    }
     */
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
               viewsToUse[i].viewModel.profilePickerEnabled = false
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
                
                AppLog.write("moveView",view.camera.getStringUid(),view.camera.getDisplayName(),orderId)
                
                orderId += 1
            }
        }
        return cams
    }
    /*
    private static func getInstance2(camera: Camera) -> DiscoveredCameraView{
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
    
    static func handleThumbChanged(_ camera: Camera){
        for dcv in views {
            if dcv.camera.xAddrId == camera.xAddrId {
                dcv.thumbChanged()
            }
        }
        for dcv in views2 {
            if dcv.camera.xAddrId == camera.xAddrId {
                dcv.thumbChanged()
            }
        }
    }
     */
}
struct DiscoveredCameraViewWrapper : View{
    
    var camera: Camera
    var model: NxvProCamerasModel
    var viewId: Int
    
    init(camera: Camera, model: NxvProCamerasModel, viewId: Int) {
        self.camera = camera
        self.model = model
        self.viewId = viewId
    }
    //remove/reset camera
    @State var showDelete = false
    @State var showReset = false
    @State var showAlert = false
    @State var camToDelete: Camera?
    
    private func resetContextMenu() -> some View{
        Group{
            let cam = camera
            Button {
                AppLog.write("Reset login invoked")
                showReset = true
                camToDelete = cam
                showAlert = true
            } label: {
                Label("Reset login", systemImage: "person.fill.xmark")
            }

            Button {
                AppLog.write("Delete camera invoked")
                showDelete = true
                camToDelete = cam
                showAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    private func resetAlert() -> Alert{
        Alert(title: Text( showDelete ? "Delete: " : "Reset: " + camToDelete!.getDisplayName()),
              message: Text(showReset ? "Reset login details" : "Remove the camera until it is discovered again?\n\n WARNING: If the camera was added manually you will have to add it again."),
                      primaryButton: .default (Text(showDelete ? "Delete" : "Reset")) {
                    
                    AppLog.write(showDelete ? "Delete: " : "Reset: " + " camera login tapped")
                    if showReset{
                            globalCameraEventListener?.resetCamera(camera: camToDelete!)
                    }else{
                        globalCameraEventListener?.deleteCamera(camera: camToDelete!)
                    }
                    showAlert = false
                    showReset = false
                    showDelete = false
                },
                    secondaryButton: .cancel() {
                    showReset = false
                    showDelete = false
                    showAlert = false
                }
            )
    }
    var body: some View{
        Group{
            DiscoCameraViewFactory.getInstanceView(camera: camera,viewId: viewId).onTapGesture {
                model.selectedCamera = camera
                DispatchQueue.main.async{
                    model.listener?.onCameraSelected(camera: camera, isCameraTap: true)
                }
            }
            .contextMenu{
                 resetContextMenu()
            }.alert(isPresented: $showAlert) {
                
               resetAlert()


            }
        }
    }
}
