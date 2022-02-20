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
#if USE_NX_TABS
    @State var camTab = NXTabItem(name: "Cameras",selected: true)
    @State var grpsTab = NXTabItem(name: "Groups")
    @State var mapTab = NXTabItem(name: "Map")
#else
    
    var dummyTab = NXTabItem(name: "Dummy")
   
    var segHeaders = ["Cameras","Groups","Map"]
    //@State var selectedHeader = "Cameras"
#endif
    init(){
        model.selectedHeader = "Cameras"
    }
    func setListener(listener: NXTabSelectedListener){
        model.listener = listener
    }
#if USE_NX_TABS
    private func tabSelected(tabIndex: Int){
        let tabs = [camTab,grpsTab,mapTab]
        for i in 0...tabs.count-1{
            if i == tabIndex{
                tabs[i].model.setSelected(selected: true)
                model.listener?.tabSelected(tabIndex: tabIndex, source: tabs[i])
            }else{
                tabs[i].model.setSelected(selected: false)
            }
        }
       
    }
    #endif
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
#if !USE_NX_TABS
            Picker("", selection: $model.selectedHeader) {
                ForEach(segHeaders, id: \.self) {
                    Text($0)
                }
            }.onChange(of: model.selectedHeader) { tabItem in
              segSelectionChanged()
            }.pickerStyle(SegmentedPickerStyle())
#else
            camTab.onTapGesture {
                tabSelected(tabIndex: 0)
            }
    
            grpsTab.onTapGesture {
                tabSelected(tabIndex: 1)
            }
            
            mapTab.onTapGesture {
                tabSelected(tabIndex: 2)
            }
#endif
        
            Spacer()
        }.frame(height: tabHeight)
    }
}


class CameraTabbedViewHeaderModel : ObservableObject{
    @Published var segHeaders = ["Live","Device","Storage","Location","Users","System"]
    @Published var selectedHeader = "Live"
    var listener: NXTabSelectedListener?
}
struct NXCameraTabHeaderView : View{
    
    @ObservedObject var model = CameraTabbedViewHeaderModel()
#if USE_NX_TABS
    @State var liveTab = NXTabItem(name: "Live",selected: true)
    @State var propsTab = NXTabItem(name: "Device info",selected: false,tabWidth: 100)
    @State var storageTab = NXTabItem(name: "Storage",selected: false,tabWidth: 150)
    //@State var remoteTab = NXTabItem(name: "Remote",selected: false,tabWidth: 150)
    @State var locTab = NXTabItem(name: "Location",selected: false,tabWidth: 150)
    @State var usersTab = NXTabItem(name: "Users",selected: false,tabWidth: 150)
    @State var sysTab = NXTabItem(name: "System",selected: false,tabWidth: 150)
    
    func setLiveName(name: String){
        liveTab.setName(name: name)
    }
    /*
    func tabSelected(tabIndex: Int){
        let tabs = [liveTab,propsTab,storageTab,locTab,usersTab,sysTab]
        for i in 0...tabs.count-1{
            if i == tabIndex{
                tabs[i].model.setSelected(selected: true)
                model.listener?.tabSelected(tabIndex: tabIndex, source: tabs[i])
            }else{
                tabs[i].model.setSelected(selected: false)
            }
        }
    }
    */
    #else
    var dummyTab = NXTabItem(name: "Dummy")
   
    
    
    private func segSelectionChanged(){
        for i in 0...model.segHeaders.count-1{
            if model.segHeaders[i] == model.selectedHeader{
                model.listener?.tabSelected(tabIndex: i, source: dummyTab)
            }
        }
    }
    func tabSelected(tabIndex: Int){
        model.selectedHeader = model.segHeaders[tabIndex]
    }
    func setLiveName(name: String){
        model.selectedHeader = name
        model.segHeaders[0] = name
    }
    #endif
    func setListener(listener: NXTabSelectedListener){
        model.listener = listener
    }
    
    
    var body: some View {
        
        HStack(spacing: 7){
            
#if USE_NX_TABS
            Spacer()
            liveTab.onTapGesture {
                tabSelected(tabIndex: 0)
            }
            propsTab.onTapGesture {
                tabSelected(tabIndex: 1)
            }
            storageTab.onTapGesture {
                tabSelected(tabIndex: 2)
            }
           
            locTab.onTapGesture {
                tabSelected(tabIndex: 3)
            }
            usersTab.onTapGesture {
                tabSelected(tabIndex: 4)
            }
            sysTab.onTapGesture {
                tabSelected(tabIndex: 5)
            }
            #else
            Picker("", selection: $model.selectedHeader) {
                ForEach(model.segHeaders, id: \.self) {
                    Text($0)
                }
            }.onChange(of: model.selectedHeader) { tabItem in
              segSelectionChanged()
            }.pickerStyle(SegmentedPickerStyle())
            
            #endif
            
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
    func onGroupStateChanged()
    func onShowMulticams()
    func openGroupMulticams(group: CameraGroup)
    func rebootDevice(camera: Camera)
    func onLocationsImported(cameraLocs: [CameraLocation])
    func onCameraLocationSelected(camera: Camera)
    func resetDiscovery()
   
}

class NxvProContentViewModel : ObservableObject, NXTabSelectedListener{
    
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
    @Published var mapHidden = true
    @Published var feedbackFormVisible: Bool = false
    
    @Published var orientation: UIDeviceOrientation
    
    @Published var selectedCameraTab = 0
    
    init(){
        orientation = UIDevice.current.orientation
    }
    func isPortrait() -> Bool{
        return orientation == UIDeviceOrientation.portrait || orientation == UIDeviceOrientation.portraitUpsideDown
    }
    func checkOrientation(){
        if isPortrait() && (mainCamera != nil || selectedCameraTab > 0)  {
            leftPaneWidth = 0
        }
    }
    func tabSelected(tabIndex: Int, source: NXTabItem) {
            selectedCameraTab = tabIndex
        if tabIndex > 1 || isPortrait() {
            //location
            leftPaneWidth = 0
            //toggleDisabled = true
        }
    }
    
    var resumePlay = false
    var mainCamera: Camera?
    var lastManuallyAddedCamera: Camera?
    
    var discoRefreshRate = 10.0
    
    
}

//only used for import camera sheet
var globalCameraEventListener: CameraEventListener?

struct NxvProContentView: View, DiscoveryListener,NetworkStateChangedListener,CameraEventListener,VLCPlayerReady, GroupChangedListener,NXTabSelectedListener,CameraChanged {
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var model = NxvProContentViewModel()
    @ObservedObject var network = NetworkMonitor.shared
    
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var cameras: DiscoveredCameras
    
    var titlebarHeight = 32.0
    @State var footHeight = CGFloat(85)
    
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
    
    //MARK: Camera tabs
    let player = SingleCameraView()
    let deviceInfoView = DeviceInfoView()
    let storageView = StorageTabbedView()
    let locationView = CameraLocationView()
    let systemView = SystemView()
    let systemLogView = SystemLogView()
    
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
                multicamView.stopAll()
                model.multicamsHidden = true
            }else if model.statusHidden{
                //model.statusHidden = false
                //stopPlaybackIfRequired()
            }
            globalLocationView.setAllCameras(allCameras: cameras.cameras)
        }
        model.mapHidden = tabIndex != 2
    }
    var body: some View {
        GeometryReader { fullView in
            let rightPaneWidth = fullView.size.width - model.leftPaneWidth
            let vheight = fullView.size.height - titlebarHeight
           
            VStack{
                HStack(alignment: .center){
                    
                    Button(action:{
                        if model.leftPaneWidth == 0{
                            model.leftPaneWidth = CGFloat(275.0)
                        }else{
                            model.leftPaneWidth = 0
                        }
                    }){
                        Image(systemName: "sidebar.left")
                    }.padding(.leading)
                        .disabled(model.toggleDisabled)
                    
                
                    Text("NX-V PRO").fontWeight(.medium)
                        .appFont(.titleBar)
                    Spacer()
                    
                    HStack{
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
                                //print("Enable geolocation")
                            } label: {
                                Label("About NX-V PRO", systemImage: "info.circle")
                            }.disabled(true)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    
                    }.padding(.trailing)
                }.sheet(isPresented: $model.feedbackFormVisible, onDismiss: {
                    model.feedbackFormVisible = false
                }, content: {
                    FeedbackSheet()
                })
                .frame(width: fullView.size.width,height: titlebarHeight)
                
                HStack(){
                    VStack(alignment: .leading,spacing: 0){
                        
                        mainTabHeader
                        
                        //Selected Tab Lists go here
                        ZStack(alignment: .topLeading){
                            camerasView.hidden(model.mainTabIndex != 0)
                            groupsView.hidden(model.mainTabIndex != 1)
                            cameraLocationsView.hidden(model.mainTabIndex != 2)
                        }
                        
                    }.sheet(isPresented: $model.showLoginSheet){
                        loginDlg
                    }
                    .hidden(model.leftPaneWidth == 0)
                    .frame(width: model.leftPaneWidth,height: vheight)
                    
                   
                   ZStack{
                        Color(UIColor.secondarySystemBackground)
                       
                       //tabs
                       VStack(spacing: 0)
                       {
#if USE_NX_TABS
                           cameraTabHeader.padding(.top,5).hidden(model.statusHidden==false)
#else
                           cameraTabHeader.padding(.bottom,5).hidden(model.statusHidden==false)
#endif
                           ZStack{
                               player.padding(.bottom).hidden(model.selectedCameraTab != 0)
                               
                               deviceInfoView.hidden(model.selectedCameraTab != 1)
                               storageView.hidden(model.selectedCameraTab != 2)
                               locationView.hidden(model.selectedCameraTab != 3)
                               systemView.hidden(model.selectedCameraTab != 4)
                               systemLogView.hidden(model.selectedCameraTab != 5)
                           }
                           
                       }.hidden(model.showLoginSheet)
                           .frame(width: rightPaneWidth,height: vheight)
                        
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
                    
                    //Spacer()
                }.sheet(isPresented: $model.showImportSheet) {
                    importSheet
                }.sheet(isPresented: $model.showImportSettingsSheet) {
                    model.showImportSettingsSheet = false
                } content: {
                    importSettingsSheet
                }
            }.onAppear{
                
                //print("body",fullView.size,model.leftPaneWidth)
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
            
            
            if model.resumePlay && model.mainCamera != nil{
                model.resumePlay = false
                model.statusHidden = false
                //connectToCamera(cam: mainCamera!)
                onCameraSelected(camera: model.mainCamera!, isMulticamView: false)
            }
            if disco.networkUnavailable || disco.cameras.hasCameras() == false {
                model.status = "Searching for cameras...."
                
                disco.start()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            RemoteLogging.log(item: "willResignActiveNotification")
            if model.mainCamera != nil {
                model.resumePlay = player.stop(camera: model.mainCamera!)
            }
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
        }
        return names
    }
    //MARK: VlcPlayerReady
    func onPlayerReady(camera: Camera) {
        DispatchQueue.main.async {
            model.statusHidden = true
            
            cameraTabHeader.setLiveName(name: camera.getDisplayName())
            deviceInfoView.setCamera(camera: camera, cameras: cameras, listener: self)
            storageView.setCamera(camera: camera)
            locationView.setCamera(camera: camera, allCameras: disco.cameras.cameras, isGlobalMap: false)
            systemView.setCamera(camera: camera)
            systemLogView.setCamera(camera: camera)
            player.showToolbar()
            
            model.mainCamera = camera
        }
        //get admin
        disco.getUsers(camera: camera)
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
            
            if model.selectedCameraTab == 0{
                model.statusHidden = false
            }
        }
    }
    
    func connectAuthFailed(camera: Camera) {
        
    }
    func onRecordingEnded(camera: Camera){
        DispatchQueue.main.async {
            storageView.setCamera(camera: camera)
        }
        
    }
    func onRecordingTerminated(camera: Camera) {
        print("MainView:onRecordingTerminated")
        //check what AppStore version does here
        onRecordingEnded(camera: camera)
    }
    
    func onIsAlive(camera: Camera) {
        
    }
    
    //MARK: CameraEventListener
    func onCameraSelected(camera: Camera,isMulticamView: Bool){
        
        if model.multicamsHidden == false{
            multicamView.stopAll()
            model.multicamsHidden = true
        }
        model.mainCamera = nil
        
        groupsView.model.selectedCamera = camera
        camerasView.model.selectedCamera = camera
        
        if camera.isAuthenticated()==false{
            loginDlg.setCamera(camera: camera, listener: self)
            model.showLoginSheet = true
        }else{
            
            model.statusHidden = false
            model.selectedCameraTab = 0
            cameraTabHeader.tabSelected(tabIndex: 0)
            player.hideControls()
            
            if camera.isNvr(){
                model.status = "Select Groups to view cameras"
                return
            }
            model.status = "Connecting to " + camera.getDisplayName() + "..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
               
                player.setCamera(camera: camera, listener: self,eventListener: self)
            })
        }
    }
    func openGroupMulticams(group: CameraGroup){
        
        if model.multicamsHidden == false{
            multicamView.stopAll()
            model.multicamsHidden = true
            model.statusHidden = false
            model.status = "Select group play"
            checkAndEnableMulticam()
            GroupHeaderFactory.resetPlayState()
        }else{
        
            stopPlaybackIfRequired()
            camerasView.enableMulticams(enable: false)
            GroupHeaderFactory.disableNotPlaying()
            
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
        }else{
            GroupHeaderFactory.resetPlayState()
            multicamView.stopAll()
            model.multicamsHidden = true
        }
    }
    private func stopPlaybackIfRequired(){
        if model.mainCamera != nil{
            player.stop(camera: model.mainCamera!)
            model.mainCamera = nil
            model.resumePlay = false
        }
    }
    func onGroupStateChanged(){
        //toggle group expand / collapse
        groupsView.touch()
       
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
        if camera.xAddr.isEmpty == false{
            //import from CSV file
            model.lastManuallyAddedCamera = nil
        }else{
            model.lastManuallyAddedCamera = camera
        }
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
    func refreshCameraProperties() {
        //cameras.cameraGroups.reset()
        
        DispatchQueue.main.async{
            groupsView.touch()
        }
    
        if let mainCam = model.mainCamera{
            deviceInfoView.setCamera(camera: mainCam, cameras: cameras, listener: self)
        }
        
    }
    func onCameraNameChanged(camera: Camera){
        cameraTabHeader.setLiveName(name: camera.getDisplayName())
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
        }
    }
    @State var networkError: Bool = false
    //MARK: NetworkChangedListener
    func onNetworkStateChanged(available: Bool) {
        print("onNetworkStateChanged",available)
        networkError = !available
        model.showNetworkUnavailble = !available
        
        
    }
    
    //MARK: Manual refesh
    func resetDiscovery() {
        //can only be called in single camera view
        stopPlaybackIfRequired()
        model.mainTabIndex = 0
        model.status = "Searching for cameras.."
        model.statusHidden = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + model.discoRefreshRate) {
            
            camerasView.enableRefresh(enable: false)
            disco.start()
            
        }
        
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
        model.status = "Select camera"
        model.showBusyIndicator = false
            //"Searching for cameras\ndiscovered: " + String(cameras.cameras.count)
        
        checkAndEnableMulticam()
        
        if model.lastManuallyAddedCamera != nil && model.lastManuallyAddedCamera!.xAddr == camera.xAddr{
            
            //model.selectedCamera = camera
            
            loginDlg.setCamera(camera: camera,listener: self)
            model.showLoginSheet = true
            
            model.lastManuallyAddedCamera = nil
        }
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
                model.status = cameras.getDiscoveredCount() > 0 ? "Select camera" : ""
            }
            if model.discoRefreshRate == 10 {
                if networkError {
                    networkError = false
                }else if(disco.camerasFound == false){
                    model.discoRefreshRate = 15
                }else{
                    model.discoRefreshRate = 30
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + model.discoRefreshRate) {
                
                camerasView.enableRefresh(enable: false)
                disco.start()
                
            }
        }
    }
    
    
    
    func zombieStateChange(camera: Camera) {
        
    }
    //MARK: Camera location list item selected
    func onCameraLocationSelected(camera: Camera){
        globalLocationView.setCamera(camera: camera, allCameras: disco.cameras.cameras)
    }
    func onLocationsImported(cameraLocs: [CameraLocation]) {
        for loc in cameraLocs{
            for cam in cameras.cameras{
                if cam.getStringUid() == loc.camUid{
                    cam.beamAngle = loc.beam
                    cam.location = [loc.lat,loc.lng]
                    cam.saveLocation()
                    cam.flagChanged()
                    break;
                }
            }
        }
        
        globalLocationView.refreshCameras(cameras: cameras.cameras)
    }
    //MARK: Reboot device
    func rebootDevice(camera: Camera){
        disco.rebootDevice(camera: camera) { cam, xmlPaths, data in
            print("RebootDevice resp",xmlPaths)
            DispatchQueue.main.async{
                model.selectedCameraTab = 0
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
