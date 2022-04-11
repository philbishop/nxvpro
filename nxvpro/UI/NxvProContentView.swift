//
//  ContentView.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI
extension View {
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide { hidden() }
        else { self }
    }
}
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

enum CameraActionEvent{
    case Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging, About, CloseSettings, ClosePresets, CloseVmd
}

protocol CameraToolbarListener{
    func itemSelected(cameraEvent: CameraActionEvent)
}

protocol NXTabSelectedListener{
    func tabSelected(tabIndex: Int, source: NXTabItem)
}

struct NXTabHeaderView: View {
    
    var tabHeight = CGFloat(32.0)
    
    @ObservedObject var model = TabbedViewHeaderModel()
 
    var dummyTab = NXTabItem(name: "Dummy")
   
    var segHeaders = [Camera.DEFAULT_TAB_NAME,"Groups","Map"]
   
    init(){
        model.selectedHeader = Camera.DEFAULT_TAB_NAME
    }
    func setListener(listener: NXTabSelectedListener){
        model.listener = listener
    }
    func changeHeader(index: Int){
        DispatchQueue.main.async{
            model.selectedHeader = segHeaders[index]
        }
    }
    private func segSelectionChanged(){
        for i in 0...segHeaders.count-1{
            if segHeaders[i] == model.selectedHeader{
                model.listener?.tabSelected(tabIndex: i, source: dummyTab)
            }
        }
    }
    
    var body: some View {
        
        HStack(spacing: 7){
           
            //tab view
            Picker("", selection: $model.selectedHeader) {
                ForEach(segHeaders, id: \.self) {
                    Text($0)
                }
            }.onChange(of: model.selectedHeader) { tabItem in
              segSelectionChanged()
            }.pickerStyle(SegmentedPickerStyle())
        
            Spacer()
        }.frame(height: tabHeight)
    }
}

enum CameraTab {
    case live,device,storage,location,users,system,none,blank
    
}
protocol NXCameraTabSelectedListener{
    func tabSelected(tabIndex: CameraTab)
}
class CameraTabbedViewHeaderModel : ObservableObject{
   
    @Published var segHeaders = ["Live","Device","Storage","Location","Users","System"]
    var segIndex = [CameraTab.live,CameraTab.device,CameraTab.storage,CameraTab.location,CameraTab.users,CameraTab.system]
    
    //var headerIndex
    @Published var selectedHeader = "Live"
    var listener: NXCameraTabSelectedListener?
}
struct NXCameraTabHeaderView : View{
    
    @ObservedObject var model = CameraTabbedViewHeaderModel()

    var dummyTab = NXTabItem(name: "Dummy")
   
    
    
    private func segSelectionChanged(){
        for i in 0...model.segHeaders.count-1{
            if model.segHeaders[i] == model.selectedHeader{
                model.listener?.tabSelected(tabIndex: model.segIndex[i])
            }
        }
    }
    func tabSelected(tab: CameraTab){
        for i in 0...model.segIndex.count-1{
            let seg = model.segIndex[i]
            if seg == tab{
                model.selectedHeader = model.segHeaders[i]
                break
            }
        }
    }
    func setCurrrent(camera: Camera){
        let name = camera.getDisplayName()
        model.selectedHeader = name
        model.segHeaders[0] = name
        
        if camera.isVirtual{
            model.segHeaders = [name,"Device","Storage","Location"]
            model.segIndex = [.live,.device,.storage,.location]
        }else if camera.isNvr(){
            model.segHeaders = ["Device","Storage","Users","System"]
            model.segIndex = [.device,.storage,.users,.system]
        }else{
            model.segHeaders = [name,"Device","Storage","Location","Users","System"]
            model.segIndex = [.live,.device,.storage,.location,.users,.system]
        }
    }

    func setListener(listener: NXCameraTabSelectedListener){
        model.listener = listener
    }
    
    
    var body: some View {
        
        HStack(spacing: 7){
            
            Picker("", selection: $model.selectedHeader) {
                ForEach(model.segHeaders, id: \.self) {
                    Text($0)
                }
            }.onChange(of: model.selectedHeader) { tabItem in
              segSelectionChanged()
            }.pickerStyle(SegmentedPickerStyle())
            
            
            Spacer()
        }
    }
}

protocol CameraEventListener : CameraLoginListener{
    func onCameraSelected(camera: Camera,isMulticamView: Bool)
    func onCameraNameChanged(camera: Camera)
    func refreshCameraProperties()
    func onImportConfig(camera: Camera)
    func onWanImportComplete()
    func onShowAddCamera()
    func onGroupStateChanged(reload: Bool)
    func onShowMulticams()
    func multicamAltModeOff()
    func multicamAltModeOn(isOn: Bool)
    func openGroupMulticams(group: CameraGroup)
    func rebootDevice(camera: Camera)
    func setSystemTime(camera: Camera)
    func onLocationsImported(cameraLocs: [CameraLocation],overwriteExisting: Bool)
    func onCameraLocationSelected(camera: Camera)
    func resetDiscovery()
    func clearStorage()
    func clearCache()
    func refreshCameras()
    func deleteCamera(camera: Camera) 
    func moveCameraToGroup(camera: Camera, grpName: String) -> [String] 
}

class NxvProContentViewModel : ObservableObject, NXCameraTabSelectedListener{
    
    var defaultLeftPanelWidth = CGFloat(275.0)
    @Published var leftPaneWidth = CGFloat(275.0)
    @Published var toggleDisabled = false
    @Published var status = "Searching for cameras..."
    @Published var networkUnavailbleStr = "Check WIFI connection\nCheck Local Network Privacy settings"
    @Published var showNetworkUnavailble: Bool = false
    @Published var showBusyIndicator = false
    @Published var showLoginSheet = false
    @Published var showImportSheet = false
    @Published var showImportSettingsSheet = false
    @Published var statusHidden = true
    @Published var mainTabIndex = 0
    @Published var multicamsHidden = true
    @Published var showMulticamAlt = false
    @Published var mapHidden = true
    @Published var feedbackFormVisible: Bool = false
    @Published var aboutVisible = false
    @Published var helpVisible = false
    @Published var orientation: UIDeviceOrientation
    
    @Published var selectedCameraTab = CameraTab.live
    
    @Published var appPlayState = AppPlayState()
    
    //isoOnMac
    @Published var isTooSmall = false
    
    @Published var mainCamera: Camera?
    var lastManuallyAddedCamera: Camera?
    
    var discoRefreshRate = 10.0
    
    init(){
        orientation = UIDevice.current.orientation
        if ProcessInfo.processInfo.isiOSAppOnMac{
            defaultLeftPanelWidth = CGFloat(325.0)
        }
    }
    
    func shouldHide(size: CGSize) -> Bool{
        if ProcessInfo.processInfo.isiOSAppOnMac{
            if size.height < 500{
                return true
            }
        }
        return false
    }
    
    func makeLeftPanVisible(){
        leftPaneWidth = defaultLeftPanelWidth
        
    }
    func isPortrait() -> Bool{
        return orientation == UIDeviceOrientation.portrait || orientation == UIDeviceOrientation.portraitUpsideDown
    }
    private func isFullScreenTab(tab: CameraTab) -> Bool{
       
        if tab == CameraTab.live {
            return false
        }
        return true
        
    }
    func checkOrientation(){
        //not require now views manage themselves
        /*
        if isPortrait() && (mainCamera != nil && isFullScreenTab(tab: selectedCameraTab))  {
            leftPaneWidth = 0
        }
         */
    }
    func tabSelected(tabIndex: CameraTab) {
        
        
        self.selectedCameraTab = tabIndex
        /*
        if isFullScreenTab(tab: selectedCameraTab) || isPortrait() {
            //location
            leftPaneWidth = 0
            //toggleDisabled = true
        }
        if let cam = mainCamera{
            print("Camera tab changed",tabIndex,cam.getDisplayName())
        }
        */
    }
}

//only used for import camera sheet
var globalCameraEventListener: CameraEventListener?

struct NxvProContentView: View, DiscoveryListener,NetworkStateChangedListener,CameraEventListener,VLCPlayerReady, GroupChangedListener,NXTabSelectedListener,CameraChanged {
    @ObservedObject private var keyboard = KeyboardResponder()
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var model = NxvProContentViewModel()
    @ObservedObject var network = NetworkMonitor.shared
    
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var cameras: DiscoveredCameras
    
    var titlebarHeight = 30.0
    @State var footHeight = CGFloat(85)
    
    let searchBar = NXSearchbar()
    
    var mainTabHeader = NXTabHeaderView()
    var cameraTabHeader =  NXCameraTabHeaderView()
    
    //left pane lists
    var camerasView: NxvProCamerasView
    var groupsView: NxvProGroupsView
    var cameraLocationsView: NxvProCameraLocationsView
    
    //optional right panes
    var multicamView = NxvProMulticamView()
    let globalLocationView = GlobalCameraMap()
    
    let loginDlg = CameraLoginSheet()
    let importSheet = ImportCamerasSheet()
    let importSettingsSheet = ImportSettingsSheet()
    let aboutSheet = AboutSheet()
    
    //MARK: Camera tabs
    let player = SingleCameraView()
    let deviceInfoView = DeviceInfoView()
    let storageView = StorageTabbedView()
    let locationView = CameraLocationView()
    let systemView = SystemView()
    let systemLogView = SystemLogView()
    
    let defaultStatusLabel = "Select camera"
    
    let disco = OnvifDisco()
    init(){
        camerasView = NxvProCamerasView(cameras: disco.cameras)
        groupsView = NxvProGroupsView(cameras: disco.cameras)
        cameraLocationsView = NxvProCameraLocationsView(cameras: disco.cameras)
        
        cameras = disco.cameras
        disco.addListener(listener: self)
        DiscoCameraViewFactory.tileWidth = CGFloat(model.leftPaneWidth)
        DiscoCameraViewFactory.tileHeight = footHeight
        
        
    }
    
    func tabSelected(tabIndex: Int, source: NXTabItem) {
        model.mainTabIndex = tabIndex
        
        if tabIndex == 2{
          
            if model.multicamsHidden == false{
               stopMulticams()
            }else{
                stopPlaybackIfRequired()
                model.selectedCameraTab = CameraTab.none
            }
            globalLocationView.setAllCameras(allCameras: cameras.cameras)
        }
        model.mapHidden = tabIndex != 2
        
        if tabIndex == 0{
            camerasView.toggleTouch()
            if model.mainCamera == nil{
                model.status = defaultStatusLabel
                model.statusHidden = false
            }
        }else{
            camerasView.disableMove()
        }
        
    }
    var body: some View {
        GeometryReader { fullView in
            let rightPaneWidth = fullView.size.width - model.leftPaneWidth
            let vheight = fullView.size.height - titlebarHeight
           
            VStack{
                HStack(alignment: .center){
                    
                    Button(action:{
                        if model.leftPaneWidth == 0{
                            model.leftPaneWidth = model.defaultLeftPanelWidth
                        }else{
                            model.leftPaneWidth = 0
                        }
                        
                        model.appPlayState.leftPaneWidth = model.leftPaneWidth
                        
                        camerasView.toggleTouch()
                    }){
                        Image(systemName: "sidebar.left")
                    }.padding(.leading,5)
                        .disabled(model.toggleDisabled)
                    
                
                    Text("NX-V PRO").fontWeight(.medium)
                        .appFont(.titleBar)
                    
                    
                    Spacer()
                   
                    
                    HStack{
                        searchBar.frame(width: 250)
                            .hidden(model.mainTabIndex != 0 || model.multicamsHidden == false ||  model.leftPaneWidth == 0)
                        
                       
                            Button(action: {
                                globalCameraEventListener?.multicamAltModeOff()
                                model.showMulticamAlt = false
                            }){
                                Image(systemName: "square.grid.2x2")
                            }.hidden(model.showMulticamAlt==false)
                        
                        
                       Menu{
                            Button {
                                model.showImportSettingsSheet = true
                            } label: {
                                Label("Import NX-V settings", systemImage: "desktopcomputer")
                            }

                           Button{
                               model.feedbackFormVisible = true
                           } label: {
                               Label("Send feedback",systemImage: "square.and.pencil")
                           }
                           Button {
                               model.helpVisible = true
                           } label: {
                               Label("Help", systemImage: "doc.circle")
                           }
                            Button {
                                model.aboutVisible = true
                            } label: {
                                Label("About NX-V PRO", systemImage: "info.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle").resizable().frame(width: 21,height: 21)
                        }.padding(.trailing)
                    
                    }.padding(.trailing)
                }.sheet(isPresented: $model.feedbackFormVisible, onDismiss: {
                    model.feedbackFormVisible = false
                }, content: {
                    FeedbackSheet()
                })
                    .sheet(isPresented: $model.helpVisible, onDismiss: {
                        model.helpVisible = false
                    }, content: {
                        ProHelpView()
                    })
                .frame(width: fullView.size.width,height: titlebarHeight)
                
                if model.shouldHide(size: fullView.size){
                    ZStack{
                        Text("Window too small to display iPad User Interface").appFont(.caption).foregroundColor(.red)
                    }
                }
                
                HStack(){
                    VStack(alignment: .leading,spacing: 0){
                        
                        mainTabHeader
                        
                        
                        //Selected Tab Lists go here
                        ZStack(alignment: .topLeading){
                            
                            camerasView.hidden(model.mainTabIndex != 0)
                            groupsView.hidden(model.mainTabIndex != 1)
                            cameraLocationsView.hidden(model.mainTabIndex != 2)
                            
                        }
                       
                    }
                    .sheet(isPresented: $model.showLoginSheet){
                        loginDlg
                    }
                    .hidden(model.leftPaneWidth == 0)
                    .frame(width: model.leftPaneWidth,height: vheight + keyboard.currentHeight,alignment: .top)
                    
                   
                   ZStack{
                        Color(UIColor.secondarySystemBackground)
                       
                       //tabs
                       VStack(spacing: 0)
                       {

                           cameraTabHeader.padding(.bottom,5).hidden(model.statusHidden==false || model.selectedCameraTab == .none)

                           ZStack{
                               player.padding(.bottom).hidden(model.selectedCameraTab != CameraTab.live)
                               
                               deviceInfoView.hidden(model.selectedCameraTab != CameraTab.device)
                               storageView.hidden(model.selectedCameraTab != CameraTab.storage)
                               locationView.hidden(model.selectedCameraTab != CameraTab.location)
                               systemView.hidden(model.selectedCameraTab != CameraTab.users)
                               systemLogView.hidden(model.selectedCameraTab != CameraTab.system)
                               
                           }
                           
                       }.hidden(model.showLoginSheet)
                           .frame(width: rightPaneWidth,height: vheight)//  + keyboard.currentHeight)
                        
                        VStack(alignment: .center){
                            Text(model.status).hidden(model.statusHidden)
                                .appFont(.smallTitle).multilineTextAlignment(.center)
                                .frame(alignment: .center)
                            //network help tip
                            Text(model.networkUnavailbleStr).appFont(.helpLabel)
                                .multilineTextAlignment(.center)
                                .hidden(model.showNetworkUnavailble == false)
                            
                            ActivityIndicator(isAnimating: .constant(true), style: .large).hidden(model.showBusyIndicator==false)
                            
                        }.hidden(model.statusHidden)
                       
                       multicamView.hidden(model.multicamsHidden)
                       globalLocationView.hidden(model.mapHidden)
                    }
                    .sheet(isPresented: $model.aboutVisible) {
                        model.aboutVisible = false
                    }content: {
                        aboutSheet
                    }
                    
                    //Spacer()
                }.sheet(isPresented: $model.showImportSheet) {
                    importSheet
                }.sheet(isPresented: $model.showImportSettingsSheet) {
                    model.showImportSettingsSheet = false
                } content: {
                    importSettingsSheet
                }.hidden(model.shouldHide(size: fullView.size))
                
            }
            .onAppear{
                
                print("body",fullView.size,model.leftPaneWidth)
            }
        }.onAppear(){
            globalCameraEventListener = self
            network.listener = self
            
            camerasView.setListener(listener: self)
            groupsView.setListener(listener: self)
            cameraLocationsView.setListener(listener: self)
            
            mainTabHeader.setListener(listener: self)
            cameraTabHeader.setListener(listener: model)
            importSheet.setListener(listener: self)
            DiscoCameraViewFactory.addListener(listener: self)
            model.statusHidden = false
            model.showBusyIndicator = true
            disco.start()
            
        }.onRotate { newOrientation in
            model.orientation = newOrientation
            model.checkOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            RemoteLogging.log(item: "willEnterForegroundNotification")
            
            model.status = ""
            
           
            if model.appPlayState.active{
                model.status = "Resuming..."
                model.statusHidden = false
                let aps = model.appPlayState
                if aps.isMulticam{
                    let smc = aps.selectedMulticam
                    
                    if let mcg = aps.group{
                        openGroupMulticams(group: mcg)
                        model.mainTabIndex = 1
                        mainTabHeader.changeHeader(index: 1)
                    }else{
                        onShowMulticams()
                    }
                    model.leftPaneWidth = model.appPlayState.leftPaneWidth
                    
                  
                    if smc.isEmpty == false{
                        for cam in cameras.cameras{
                            if cam.isNvr(){
                                for vcam in cam.vcams{
                                    if vcam.getStringUid() == smc{
                                        multicamView.setSelectedCamera(camera: vcam,isLandscape: true)
                                        
                                        break
                                    }
                                }
                            }else{
                                if cam.getStringUid() == smc{
                                    multicamView.setSelectedCamera(camera: cam,isLandscape: true)
                                    break
                                }
                            }
                        }
                    }
                  
                    //don't reset as we have reselected
                    
                }else if aps.camera != nil{
                    model.statusHidden = false
                    onCameraSelected(camera: aps.camera!,isMulticamView: false)
                }
                
            }else if disco.networkUnavailable || disco.cameras.hasCameras() == false {
                model.status = "Searching for cameras...."
                
                disco.start()
            }else{
                model.status = " Select camera"
            }
            FileHelper.purgeOldRemoteVideos()
            
            nxvproApp.startZeroConfig()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            RemoteLogging.log(item: "willResignActiveNotification")
            model.appPlayState.active = false
            model.appPlayState.leftPaneWidth = model.leftPaneWidth
            
            let aps = model.appPlayState
            
            if model.appPlayState.camera != nil {
                //model.resumePlay = player.stop(camera: model.mainCamera!)
                //model.lastSelectedCameraTab = model.selectedCameraTab
                
                if player.stop(camera: aps.camera!){
                    model.appPlayState.active = true
                    //model.appPlayState.camera = model.mainCamera
                    model.appPlayState.selectedCameraTab = model.selectedCameraTab
                }
            }else if model.multicamsHidden == false{
                
                //close multicam
                stopMulticams()
                
                model.appPlayState.active = true
                model.appPlayState.isMulticam = true
                if let smc = multicamView.selectedCamera(){
                    model.appPlayState.selectedMulticam = smc.getStringUid()
                }
                //other appPlayState should already be set
                
                model.statusHidden = false
                model.mainTabIndex = 0
                model.selectedCameraTab = CameraTab.live
                model.status = ""
                //model.makeLeftPanVisible()
            }
            
            nxvproApp.stopZeroConfig()
        }
        
    }
    
    private func checkAndEnableMulticam(){
        DispatchQueue.main.async{
            var nAuth = 0
            var nFavs = 0
            for cam in cameras.cameras {
                
                if cam.isAuthenticated() {
                    if cam.isFavorite{
                        nFavs += 1
                    }
                
                }
            }
            
            //print("checkAndEnableMulticam",nFavs)
            
            camerasView.enableMulticams(enable: nFavs > 1)
        }
    }
    //MARK: Delete camera
    func deleteCamera(camera: Camera) {
       
        let dq  = DispatchQueue(label: "delete_cam")
        dq.async{
            FileHelper.deleteCamera(camera: camera)
            DispatchQueue.main.async{
                
                DiscoCameraViewFactory.reset()
                cameras.removeCamera(camera: camera)
               
                
                if model.mainCamera != nil{
                    if model.mainCamera!.getBaseFileName() == camera.getBaseFileName(){
                        stopPlaybackIfRequired()
                        model.status = "Camera removed"
                        model.statusHidden = false
                        model.showNetworkUnavailble = false
                        model.selectedCameraTab = .live
                        model.mainTabIndex = 0
                    }
                }
            }
        }
    }
    //MARK: CameraChanged impl
    func onCameraChanged() {
        //enable / disable multicam button
        print("NxvProContentView:onCameraChanged")
        DispatchQueue.main.async{
            checkAndEnableMulticam()
        }
    }
    func getSrc() -> String {
        return "mainVc"
    }
    //MARK: GroupChangeListener
    func moveCameraToGroup(camera: Camera, grpName: String) -> [String] {
        print("moveCameraToGroup",camera.getDisplayAddr(),grpName)
        
        cameras.cameraGroups.addCameraToGroup(camera: camera, grpName: grpName)
        let names = cameras.cameraGroups.getNames()
        
        DispatchQueue.main.async{
            //groups will have been reloaded from JSON so repopulate the camera objects
            cameras.cameraGroups.populateCameras(cameras: cameras.cameras)
            groupsView.touch()
            camerasView.touch()
            
            if grpName == CameraGroup.DEFAULT_GROUP_NAME || grpName == CameraGroup.MISC_GROUP{
               //switch to main tab
                model.mainTabIndex = 0
                mainTabHeader.changeHeader(index: 0)
            }else{
                model.mainTabIndex = 1
                mainTabHeader.changeHeader(index: 1)
            }
        
        }
        return names
    }
    //MARK: VlcPlayerReady
    private func initCameraTabs(camera: Camera){
        cameraTabHeader.setCurrrent(camera: camera)
        deviceInfoView.setCamera(camera: camera, cameras: cameras, listener: self)
        storageView.setCamera(camera: camera)
        locationView.setCamera(camera: camera, allCameras: disco.cameras.cameras, isGlobalMap: false)
        systemView.setCamera(camera: camera)
        systemLogView.setCamera(camera: camera)
    }
    func reconnectToCamera(camera: Camera) {
        print("NxvProContentView:reconnectToCamera",camera.getStringUid())
        stopPlaybackIfRequired()
        onCameraSelected(camera: camera, isMulticamView: false)
    }
    func onPlayerReady(camera: Camera) {
        DispatchQueue.main.async {
            model.statusHidden = true
            
            initCameraTabs(camera: camera)
            model.selectedCameraTab = .live
            model.tabSelected(tabIndex: .live)
        
            player.showToolbar()
        
            if model.appPlayState.active{
                
                //reselect  last camera toolbar item
                let lst = model.appPlayState.selectedCameraTab
                model.selectedCameraTab = lst
                model.tabSelected(tabIndex: lst)
                cameraTabHeader.tabSelected(tab: lst)
                
                model.leftPaneWidth = model.appPlayState.leftPaneWidth
                
            }else{
                model.appPlayState.camera = camera
            }
            
            
            
            model.mainCamera = camera
        }
        
    }
    
    func onBufferring(camera: Camera, pcent: String) {
        DispatchQueue.main.async{
            model.status = pcent
        }
    }
    
    func onSnapshotChanged(camera: Camera) {
        DispatchQueue.main.async{
            let dcv = DiscoCameraViewFactory.getInstance(camera: camera)
            dcv.thumbChanged()
        }
    }
    
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async{
            model.status = error
            
            if model.selectedCameraTab == CameraTab.live{
                model.statusHidden = false
            }
        }
    }
    
    func connectAuthFailed(camera: Camera) {
        
    }
    func onRecordingEnded(camera: Camera){
        storageView.touchOnDevice()
        DispatchQueue.main.async {
            storageView.onDeviceView.refresh()
        }
        
    }
    func onRecordingTerminated(camera: Camera) {
        print("MainView:onRecordingTerminated")
        //check what AppStore version does here
        onRecordingEnded(camera: camera)
    }
    
    func autoSelectCamera(camera: Camera) {
        //no used here but in multicam view
    }
    
    //MARK: CameraEventListener
    
    func onCameraSelected(camera: Camera,isMulticamView: Bool){
        
        if model.multicamsHidden == false{
           stopMulticams()
        }else{
            stopPlaybackIfRequired()
        }
        model.mainCamera = nil
        model.appPlayState.reset()
        
        groupsView.model.selectedCamera = camera
        camerasView.model.selectedCamera = camera
        model.selectedCameraTab = .none
        
        if camera.isAuthenticated()==false{
            loginDlg.setCamera(camera: camera, listener: self)
            model.showLoginSheet = true
        }else{
            
           
            player.hideControls()
            
            if camera.isNvr(){
               
                //model.status = "Select Groups to view cameras"
                model.mainCamera = camera
                model.statusHidden = true
                model.selectedCameraTab = .device
                initCameraTabs(camera: camera)
                return
            }
            
            model.statusHidden = false
            model.selectedCameraTab = .none
            cameraTabHeader.tabSelected(tab: .live)
            
            model.status = "Connecting to " + camera.getDisplayName() + "..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
               
                player.setCamera(camera: camera, listener: self,eventListener: self)
            })
        }
    }
    func openGroupMulticams(group: CameraGroup){
        
        if model.multicamsHidden == false{
            stopMulticams()
            model.statusHidden = false
            model.status = defaultStatusLabel
            
        }else{
        
            stopPlaybackIfRequired()
            camerasView.enableMulticams(enable: false)
            camerasView.setMulticamActive(active: true)
            GroupHeaderFactory.disableNotPlaying()
            
            //prepare for a resume
            model.appPlayState.reset()
            model.appPlayState.isMulticam = true
            model.appPlayState.group = group
            model.appPlayState.multicams = nil
            
            DispatchQueue.main.async{
                let favs = self.cameras.getFavCamerasForGroup(cameraGrp: group)
                
                self.multicamView.setCameras(cameras: favs)
                self.multicamView.playAll()
                self.model.multicamsHidden = false
            }
        }
    
    }
    func onShowMulticams(){
        if model.multicamsHidden{
            stopPlaybackIfRequired()
            
            let favs = cameras.getAuthenticatedFavorites()
            multicamView.setCameras(cameras: favs)
            multicamView.playAll()
            model.multicamsHidden = false
            camerasView.setMulticamActive(active: true)
            GroupHeaderFactory.enableAllPlay(enable: false)
            
            //prepare for a resume
            model.appPlayState.reset()
            model.appPlayState.isMulticam = true
            model.appPlayState.group = nil
            model.appPlayState.multicams = favs
            
            
        }else{
            stopMulticams()
        }
    }
    func stopMulticams(){
        model.selectedCameraTab = CameraTab.none
        multicamView.stopAll()
        model.multicamsHidden = true
        model.showMulticamAlt = false
        
        checkAndEnableMulticam()
        camerasView.setMulticamActive(active: false)
        GroupHeaderFactory.resetPlayState()
    }
    func multicamAltModeOff() {
        multicamView.disableAltMode()
    }
    func multicamAltModeOn(isOn: Bool){
        model.showMulticamAlt = isOn
    }
    private func stopPlaybackIfRequired(){
        if model.mainCamera != nil{
            player.stop(camera: model.mainCamera!)
            model.mainCamera = nil
            model.appPlayState.active = false
        }
    }
    func onGroupStateChanged(reload: Bool = false){
        //toggle group expand / collapse
        if reload{
            cameras.cameraGroups.reset()
        }
        groupsView.touch()
        cameraLocationsView.touch()
    }
    func onShowAddCamera() {
        model.showImportSheet = true
    }
    func onWanImportComplete() {
        //cameras.allCameras.reset()
        disco.flushAndRestart()
    }
    func onImportConfig(camera: Camera) {
        //show login after added
        model.lastManuallyAddedCamera = camera
        onImportConfigComplete()
    }
    func onImportConfigComplete(){
        print("onImportConfigComplete")
        
        disco.cameras.allCameras.loadFromXml()
        
            
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            //self.closeHelpViews()
            model.status = "Camera added"
            disco.start()
        })
        
    }
    func refreshCameras(){
        //need to force a complete refresh here
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute: {
            
            self.resetDiscovery()
        })
    }
    func refreshCameraProperties() {
        
        DispatchQueue.main.async{
            groupsView.touch()
        }
    
        if let mainCam = model.mainCamera{
            deviceInfoView.setCamera(camera: mainCam, cameras: cameras, listener: self)
        }
        
    }
    func onCameraNameChanged(camera: Camera){
        cameraTabHeader.setCurrrent(camera: camera)
    }
    
    func loginCancelled() {
        model.showLoginSheet = false
    }
    
    func loginStatus(camera: Camera, success: Bool) {
        if success {
            model.showLoginSheet = false
            cameras.cameraUpdated(camera: camera)
            DiscoCameraViewFactory.handleCameraChange(camera: camera)
            onCameraSelected(camera: camera, isMulticamView: false)
            
            if camera.isNvr(){
                groupsView.highlightGroupNvr(camera: camera)
                model.mainTabIndex = 1
                mainTabHeader.changeHeader(index: 1)
            }
        }
    }
    @State var networkError: Bool = false
    //MARK: NetworkChangedListener
    func onNetworkStateChanged(available: Bool) {
        print("onNetworkStateChanged",available)
        networkError = !available
        model.showNetworkUnavailble = !available
        
        
    }
    
    //MARK: ClearStorage
    func clearCache() {
        FileHelper.deleteSdCache()
    }
    func clearStorage() {
        clearStorageImpl()
    }
    private func clearStorageImpl(deleteFiles: Bool = true) {
        
        stopPlaybackIfRequired()
        model.mainTabIndex = 0
        model.statusHidden = false
        model.selectedCameraTab = CameraTab.none
        
        if deleteFiles{
            FileHelper.deleteAll()
        }
        model.status = "Waiting for refresh..."
        
        DiscoCameraViewFactory.reset()
        
        model.statusHidden = false
        model.showNetworkUnavailble = false
       
        disco.flushAndRestart()
        
        cameraLocationsView.touch()
    }
    //MARK: Manual refesh
    func resetDiscovery() {
        clearStorageImpl(deleteFiles: false)
        
    }
    
    //MARK: DiscoveryListener
    func networkNotAvailabled(error: String) {
        print("OnvifDisco:networkNotAvailabled",error)
        networkError = true
        DispatchQueue.main.async {
            if model.showBusyIndicator {
                model.showBusyIndicator = false
                let ns = "Unable to connect to network\nWill try again in few seconds..."
                
                model.showNetworkUnavailble = true
                model.status = ns
                
            }
            //showCamerasFoundStatus()
        }
        
        RemoteLogging.log(item: "Network unavailable " + error)
    }
    func cameraAdded(camera: Camera) {
        print("OnvifDisco:cameraAdded",camera.getDisplayName())
        model.status = defaultStatusLabel
        model.showNetworkUnavailble = false
        model.showBusyIndicator = false
            //"Searching for cameras\ndiscovered: " + String(cameras.cameras.count)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
            checkAndEnableMulticam()
            
            if model.lastManuallyAddedCamera != nil && model.lastManuallyAddedCamera!.xAddr == camera.xAddr{
                
                model.mainCamera = camera
                camerasView.model.selectedCamera = camera
                loginDlg.setCamera(camera: camera,listener: self)
                model.showLoginSheet = true
                
                model.lastManuallyAddedCamera = nil
            }
        })
    }
    
    
    func cameraChanged(camera: Camera) {
        print("Camera changed->does nothing",camera.getStringUid())
    }
    
    func discoveryError(error: String) {
        print("OnvifDisco:discoveryError",error)
    }
    
    func discoveryTimeout() {
        AppLog.write("discoveryTimeout")
        DispatchQueue.main.async {
            model.showBusyIndicator = false
            camerasView.enableRefresh(enable: true)
        }
        if cameras.cameras.count == 0  || networkError {
            
            DispatchQueue.main.async{
                if networkError {
                    model.status = "Searching for cameras, trying again\nPlease wait..."
                }else {
                    model.status = "No cameras found, trying again\nPlease wait..."
                }
                model.showNetworkUnavailble = disco.numberOfDiscos > 1
                //showCamerasFoundStatus()
            }
            networkError = false
            disco.start()
        }else{
            DispatchQueue.main.async{
                model.status = cameras.getDiscoveredCount() > 0 ? defaultStatusLabel : ""
                model.showNetworkUnavailble = false
            }
            if model.discoRefreshRate == 10 {
                if networkError {
                    networkError = false
                }else if(disco.camerasFound == false){
                    model.discoRefreshRate = 15
                }else{
                    if model.multicamsHidden == false{
                        model.discoRefreshRate = 45
                    }else{
                        model.discoRefreshRate = 30
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + model.discoRefreshRate) {
                
                camerasView.enableRefresh(enable: false)
                disco.start()
                
            }
        }
        if cameras.cameras.count > 0{
            let flatMap = FileHelper.exportMapSettings(cameras:  cameras.cameras)
            zeroConfigSyncHandler.flatMap = flatMap
            
            let flatWan = FileHelper.exportWanSettings(cameras: cameras.cameras)
            zeroConfigSyncHandler.flatWan = flatWan
            
            let flatGroups = FileHelper.exportGroupSettings(cameraGroups: disco.cameras.cameraGroups)
            zeroConfigSyncHandler.flatGroups = flatGroups
            
            let flatStorage = FileHelper.exportFtpSettings(cameras: cameras.cameras)
            zeroConfigSyncHandler.flatFtp = flatStorage
        
            //server logging pf pro installs
            #if DEBUG
                print("DEBUG not sending pro install to server")
            #else
                NXVProxy.sendInstallNotifcationIfNew()
            #endif
        }
    }
    
    
    
    func zombieStateChange(camera: Camera) {
        
    }
    //MARK: Camera location list item selected
    func onCameraLocationSelected(camera: Camera){
        globalLocationView.setCamera(camera: camera, allCameras: disco.cameras.cameras)
    }
    func onLocationsImported(cameraLocs: [CameraLocation],overwriteExisting: Bool) {
        for loc in cameraLocs{
            for cam in cameras.cameras{
                if cam.isNvr(){
                    for vcam in cam.vcams{
                        if vcam.getStringUid() == loc.camUid{
                            importLocation(cam: vcam,loc: loc,overwriteExisting: overwriteExisting)
                            break;
                        }
                    }
                    continue
                }
                if cam.getStringUid() == loc.camUid{
                    importLocation(cam: cam,loc: loc,overwriteExisting: overwriteExisting)
                    break;
                }
            }
        }
        
        cameraLocationsView.touch()
        groupsView.touch()
        
        //globalLocationView.refreshCameras(cameras: cameras.cameras)
    }
    private func importLocation(cam: Camera,loc: CameraLocation,overwriteExisting: Bool){
        cam.loadLocation()
        if cam.hasValidLocation() && overwriteExisting == false{
            return
        }
        cam.beamAngle = loc.beam
        cam.location = [loc.lat,loc.lng]
        cam.saveLocation()
        cam.flagChanged()
    
    }
    //MARK: Set SystemDateTime
    func setSystemTime(camera: Camera) {
        disco.setSystemTime(camera: camera)
    }
    //MARK: Reboot device
    func rebootDevice(camera: Camera){
        disco.rebootDevice(camera: camera) { cam, xmlPaths, data in
            print("RebootDevice resp",xmlPaths)
            DispatchQueue.main.async{
                model.selectedCameraTab = CameraTab.live
                model.statusHidden = false
                
                var rebootMsg = ""
                if xmlPaths.count > 0{
                    let paths = xmlPaths[0].components(separatedBy: "/")
                    rebootMsg  = paths[1]
                    //AppDelegate.Instance.showMessageAlert(title: "Reboot", message: msg)
                }
                
                stopPlaybackIfRequired()
                //show network unavailble
                //force stop multicam
                if rebootMsg.isEmpty{
                    model.status = "Waiting for reboot"
                }else{
                    model.status = rebootMsg
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2,execute:{
                        model.status = ""
                    })
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProContentView()
    }
}
