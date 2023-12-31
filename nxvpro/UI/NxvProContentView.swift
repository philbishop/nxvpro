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
    func toolTip(_ toolTip: String) -> some View {
        return self
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
    case Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging, About, CloseSettings, ClosePresets, CloseVmd, bodyDetection
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
                //.fixedSize()
            
            Spacer()
        }
    }
}

class NxvProContentViewModel : ObservableObject, NXCameraTabSelectedListener{
    
    var defaultLeftPanelWidth = CGFloat(275.0)
    @Published var leftPaneWidth = CGFloat(275.0)
    
    @Published var screenWidth = UIScreen.main.bounds.width //iPhone only
    @Published var toggleDisabled = false
    @Published var searchBarWidth = CGFloat(250)
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
    //@Published var orientation: UIDeviceOrientation
    @Published var isPortrait = false
    @Published var searchHasFocus = false
    @Published var selectedCameraTab = CameraTab.live
    
    @Published var appPlayState = AppPlayState()
    
    @Published var isFullScreen = false
    @Published var backgroundColor = Color(UIColor.systemBackground)
    //isoOnMac
    @Published var isoOnMac=false
    @Published var isTooSmall = false
    
    @Published var mainCamera: Camera?
    var lastManuallyAddedCamera: Camera?
    var defaultTilebarHeight = 30.0
    var topPadding = 0.0
    var titlebarHeight = 30.0
    var discoRefreshRate = 10.0
    var discoFirstTime = true
    var isPhone = false
    var isImportMode = false
    
    @Published var audioMuted = false
    @Published var audioMenuIcon = "speaker.wave.3"
    @Published var audioMenuLabel = "Toggle global audio"
    @Published var menuVizState = 1
    
    init(){
        //orientation = UIDevice.current.orientation
        if ProcessInfo.processInfo.isiOSAppOnMac{
            //defaultLeftPanelWidth = CGFloat(325.0)
            // leftPaneWidth = defaultLeftPanelWidth
            titlebarHeight = 10
            topPadding = 10
            isoOnMac = true
        }
        if UIDevice.current.userInterfaceIdiom == .phone{
            isPhone = true
            if UIScreen.main.bounds.width == 320{
                searchBarWidth = 0
            }else{
                searchBarWidth = 130
            }
        }
        
        audioMuted = AppSettings.isGlobalAudioMuted()
        
        setAudiMenuIcon()
    }
    private func setAudiMenuIcon(){
        if audioMuted{
            audioMenuIcon = "speaker.slash"
            audioMenuLabel = "Turn global audio ON"
        }else{
            audioMenuIcon = "speaker.wave.3"
            audioMenuLabel = "Turn global audio OFF"
        }
    }
    func toggleGlobalAudioMute(){
        audioMuted = !audioMuted
        UserDefaults.standard.set(audioMuted,forKey: Camera.AUDIO_MUTE_KEY)
        setAudiMenuIcon()
    }
    
    var lastGoodPlayState: AppPlayState?
    func clonePlayState(){
        lastGoodPlayState = appPlayState.clone()
        AppLog.write("clonePlayState",lastGoodPlayState!.dump())
    }
    func setFullScreen(fs: Bool){
        isFullScreen = fs
        backgroundColor = fs ? Color.black : Color(UIColor.systemBackground)
    }
    func shouldHide(size: CGSize) -> Bool{
        if ProcessInfo.processInfo.isiOSAppOnMac{
            if size.height < 500{
                return true
            }
        }
        return false
    }
    func autoCloseLeftPane(){
        if leftPaneWidth == defaultLeftPanelWidth{
            leftPaneWidth = 0
        }
    }
    func makeLeftPanVisible(){
        leftPaneWidth = defaultLeftPanelWidth
        
    }
    /*
     func isPortrait() -> Bool{
     return orientation == UIDeviceOrientation.portrait || orientation == UIDeviceOrientation.portraitUpsideDown
     }
     */
    private func isFullScreenTab(tab: CameraTab) -> Bool{
        
        if tab == CameraTab.live {
            return false
        }
        return true
        
    }
    func checkOrientation(){
        
    }
    func tabSelected(tabIndex: CameraTab) {
        
        UIApplication.shared.endEditing()
        self.selectedCameraTab = tabIndex
    }
}
protocol IosCameraEventListener : CameraEventListener{
    func toggleSideBar()
    func hideSideBar()
    func resetDigitalZoom()
    func toggleSidebarDisabled(disabled: Bool)
    func onSnapshotChanged(camera: Camera)
    func onSearchFocusChanged(focused: Bool)
    func onToggleFullScreen()
    func isFullScreen()->Bool
    func onMulticamModeChanged(_ newMode: Multicam.Mode)
    func onGlobalAudioMute(muted: Bool);
}
//only used for import camera sheet
var globalCameraEventListener: IosCameraEventListener?
var globalProPlayerListener: ProPlayerEventListener?

struct NxvProContentView: View, DiscoveryListener,NetworkStateChangedListener,IosCameraEventListener,VLCPlayerReady, GroupChangedListener,NXTabSelectedListener,CameraChanged {
    
    //MARK: EEN listener
    func eenRegitsrationCompleted() {
         //invoked when registration completed
        if let eenGroupName = eenApi.getFirstCameraBridgeId(){
            if let cg = cameras.cameraGroups.getGroupFromName(eenGroupName){
                DispatchQueue.main.async{
                    
                    openGroupMulticams(group: cg)
                }
            }
        }
    }
    
    
    //MARK: Network Streams
    func networkStreamsAdded(streamnUrl: [String]) {
        //dummy from OSX import from CSV/Text file
    }
    func networkStreamAdded(streamnUrl: String,name: String) {
        
        var nameToUse = name
        var groupName = ""
        if name.contains(":"){
            let parts = name.components(separatedBy: ":")
            if parts.count==2{
                groupName = parts[0]
                nameToUse = parts[1]
            }
        }
        DispatchQueue.main.async{
            if let netCam = camerasView.netStream.addCameraWithName(netStream: streamnUrl, name: nameToUse){
                
                if groupName.isEmpty{
                     onCameraSelected(camera: netCam, isCameraTap: false)
                }else{
                    cameraLocationsView.touchNetStreams()
                    moveCameraToGroup(camera: netCam, grpName: groupName)
                   
                }
            }
        }

    }
    //MARK: UI Helper merge all cameras
    private func hasCameras() -> Bool{
        return getAllCameras(cameras: cameras.cameras).count > 0
    }
    private func getAllCameras(cameras: [Camera]) -> [Camera]{
        /*
        var allCams = [Camera]()
        allCams.append(contentsOf: cameras)
        let nsCams = camerasView.netStream.cameras
        if nsCams.count > 0{
            allCams.append(contentsOf: nsCams)
        }
        
        allCams.sort{
            $0.displayOrder < $1.displayOrder
        }
        
        return allCams
         */
        return CameraUtils.getAllCameras(cameras: cameras, netStreams: camerasView.netStream.cameras)
    }
    func getAllFavorites() -> [Camera] {
        var allFavs = [Camera]()
        let favs = cameras.getFavourites()
        if favs.count>0{
            allFavs.append(contentsOf: favs)
        }
        
        let ns = camerasView.netStream.cameras
        for cam in ns{
            if cam.isFavorite{
                allFavs.append(cam)
            }
        }
        allFavs.sort{
            $0.displayOrder < $1.displayOrder
        }
        return allFavs
    }
    func getAuthenticatedFavs() -> [Camera]{
        var allFavs = [Camera]()
        let favs = cameras.getAuthenticatedFavorites()
        if favs.count>0{
            allFavs.append(contentsOf: favs)
        }
        let ns = camerasView.netStream.cameras
        for cam in ns{
            if cam.isFavorite{
                allFavs.append(cam)
            }
        }
        if AppSettings.IS_PRO == false{
            while allFavs.count > 4{
                allFavs.remove(at: 0)
            }
        }
        allFavs.sort{
            $0.displayOrder < $1.displayOrder
        }
        for cam in allFavs{
         
            debugPrint("AUTH FAV",cam.getDisplayName(),cam.displayOrder)
        }
        return allFavs
    }
    
    
    //MARK: CameraEventListener
   
    func OnGroupExpandStateChanged(group: CameraGroup, expanded: Bool) {
        AppLog.write("NxvProContentView:saveGroupStates",group.name,expanded)
        onGroupStateChanged(reload: false)
        
        //save state
        group.camsVisible = expanded
        GroupHeaderFactory.saveGroupStates()
        
    }
    
    func openMiniMap(group: CameraGroup) {
        
    }
    
    func onCloudSessionStarted(started: Bool) {
        
    }
    
    func canAddFavorite() -> Bool {
        return true
    }
    
    @ObservedObject private var keyboard = KeyboardResponder()
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var model = NxvProContentViewModel()
    @ObservedObject var network = NetworkMonitor.shared
    
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var cameras: DiscoveredCameras
    
    
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
    
    private func showSelectCamera(){
        if model.mainCamera != nil{
            return
        }
        if model.status.contains("Connecting to") == false{
            model.status = defaultStatusLabel
        }
    }
    
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
        //cancel autonatic switch
        model.discoFirstTime = false
        if tabIndex == 2{
            
            if model.multicamsHidden == false{
                stopMulticams()
            }else{
                stopPlaybackIfRequired()
                model.selectedCameraTab = CameraTab.none
            }
            let allCams = getAllCameras(cameras: cameras.cameras)
            globalLocationView.setAllCameras(allCameras: allCams)
        }
        model.mapHidden = tabIndex != 2
        
        if tabIndex == 0{
            camerasView.toggleTouch()
            if model.mainCamera == nil{
                //model.status = defaultStatusLabel
                showSelectCamera()
                model.statusHidden = false
            }
        }else{
            camerasView.disableMove()
        }
        
    }
    private func updateStatusAsync(_ text: String){
        DispatchQueue.main.async{
            
        }
    }
    private func setSlidebarWidth(_ w: CGFloat){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.model.leftPaneWidth = w
        }
    }
    func hideSideBar() {
        if model.leftPaneWidth > 0{
            toggleSideBar()
        }
    }
    func toggleSideBar(){
        DispatchQueue.main.async {
            
            if model.leftPaneWidth == 0{
               
                if model.isPhone{
                    if model.multicamsHidden == false{
                        stopMulticams()
                    }else{
                        stopPlaybackIfRequired()
                    }
                    model.selectedCameraTab = .blank
                    
                    model.mainCamera = nil
                    model.status = ""
                    model.appPlayState.reset()
                    showSelectCamera()
                    
                    model.statusHidden = false
                
                    setSlidebarWidth(model.defaultLeftPanelWidth)
                }else{
                    model.leftPaneWidth = model.defaultLeftPanelWidth
                }
                
            }else{
                model.leftPaneWidth = 0
            }
            
            model.appPlayState.leftPaneWidth = model.leftPaneWidth
            if model.appPlayState.active{
                model.appPlayState.save()
            }
            
            camerasView.toggleTouch()
            
        }

    }
    func toggleSwipe(){
        //needs animation
    }
    
    private func appTitleBarView(size: CGSize,isPad: Bool) -> some View{
        HStack(alignment: .center){
            
            // ZStack{
            Button(action:{
                toggleSideBar()
            }){
                Image(systemName: "sidebar.left")
            }.padding(.leading,5)
                .disabled(model.toggleDisabled)
            
            //}.zIndex(1)
            Text("NX-V PRO").fontWeight(.medium).lineLimit(1)
                .appFont(.titleBar)
                
            Spacer()
            
            
            HStack(spacing: 5){
                if model.searchBarWidth > 0{
                    searchBar.frame(width: model.searchBarWidth)
                        .hidden(model.mainTabIndex != 0 || model.multicamsHidden == false ||  model.leftPaneWidth == 0
                                || model.toggleDisabled)
                        
                   
                }
                
                Menu{
                    Button{
                        debugPrint("Toggle global audio currently",model.audioMuted)
                        model.toggleGlobalAudioMute()
                        globalCameraEventListener?.onGlobalAudioMute(muted: model.audioMuted)
                        
                    } label: {
                        Label(model.audioMenuLabel,systemImage: model.audioMenuIcon )
                    }
                    
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
                }
                    .disabled(model.toggleDisabled)
                
            }.padding(.trailing)
            
        }.appFont(.body)
        .zIndex(1)
            .sheet(isPresented: $model.feedbackFormVisible, onDismiss: {
                model.feedbackFormVisible = false
            }, content: {
                FeedbackSheet()
            })
            .sheet(isPresented: $model.helpVisible, onDismiss: {
                model.helpVisible = false
            }, content: {
                ProHelpView()
            })
            .hidden(model.titlebarHeight == 0.0)
            .frame(width: size.width,height: model.titlebarHeight)
        
    }
    
    var body: some View {
        
        VStack(alignment: .leading){
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            GeometryReader { fullView in
                //let fullWidth = fullView.size.width
                //let rightPaneWidth = fullView.size.width - model.leftPaneWidth
                let hoff = model.isFullScreen ? 0.0 : model.titlebarHeight - model.topPadding
                let vheight = fullView.size.height - hoff
                let tinyScreen = UIScreen.main.bounds.width == 320
                
                VStack(alignment: .leading, spacing: 0){
                    
                    if model.isFullScreen == false{
                        appTitleBarView(size: fullView.size,isPad: isPad)
                            
                    }
                    
                    HStack(spacing: 0){
                        VStack(alignment: .leading,spacing: 0){
                            
                            mainTabHeader
                            
                            
                            //Selected Tab Lists go here
                            ZStack(alignment: .topLeading){
                                //Color(UIColor.systemBackground)
                                camerasView.hidden(model.mainTabIndex != 0)
                                groupsView.hidden(model.mainTabIndex != 1)
                                cameraLocationsView.hidden(model.mainTabIndex != 2)
                                
                            }
                            
                        }
                        .background(Color(UIColor.systemBackground))
                        .zIndex(2)
                       /*
                        .onSwiped(.left){
                            withAnimation(.easeOut(duration: 0.25)) {
                                
                                model.leftPaneWidth = 0
                            }
                        }
                        */
                        .sheet(isPresented: $model.showLoginSheet){
                            loginDlg
                        }
                        .hidden(model.leftPaneWidth == 0)
                        .frame(width: model.leftPaneWidth,height: vheight  + (keyboard.currentHeight),alignment: .top)
                        
                        
                        ZStack(alignment: .leading){
                            //Color(UIColor.secondarySystemBackground)
                            
                            //tabs
                            VStack(spacing: 0)
                            {
                                if model.isFullScreen == false{
                                    cameraTabHeader.padding(.bottom,0)
                                        //.hidden(model.statusHidden==false || model.selectedCameraTab == .none)
                                        .hidden(model.mainCamera==nil)
                                        .zIndex(3)
                                }
                                
                                ZStack(alignment: .center){
                                    player
                                        .padding(.bottom)
                                        .hidden(model.selectedCameraTab == CameraTab.blank)
                                        .scaleEffect(x: tinyScreen ? 0.9 : 1.0,y: tinyScreen ? 0.9 : 1.0)
                                        .offset(x: tinyScreen ? -20 : 0, y: 0)
                                       
                                    
                                    deviceInfoView.hidden(model.selectedCameraTab != CameraTab.device)
                                    storageView.hidden(model.selectedCameraTab != CameraTab.storage)
                                    locationView.hidden(model.selectedCameraTab != CameraTab.location)
                                    systemView.hidden(model.selectedCameraTab != CameraTab.users)
                                    systemLogView.hidden(model.selectedCameraTab != CameraTab.system)
                                    
                                }.background(model.selectedCameraTab == CameraTab.live && model.statusHidden ? .black : Color(UIColor.secondarySystemBackground))
                                    //.scaleEffect(x: (isPad && rightPaneWidth  < 830) ? (fullWidth/834.0) : 1,y: 1)
                                    
                            }
                            .hidden(model.showLoginSheet || model.searchHasFocus)
                            .frame(width: fullView.size.width - model.leftPaneWidth,height: vheight + keyboard.currentHeight)
                            .scaleEffect(x: 1.0,y: tinyScreen ? 0.9 : 1.0)
                            
                            
                            
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
                            .frame(width: fullView.size.width - model.leftPaneWidth)
                        
                            multicamView.hidden(model.multicamsHidden)
                               
                            globalLocationView.hidden(model.mapHidden)
                        }
                        
                        .background(Color(UIColor.secondarySystemBackground))
                            .sheet(isPresented: $model.aboutVisible) {
                                model.aboutVisible = false
                            }content: {
                                aboutSheet
                            }
                        
                        //Spacer()
                    }
                    .padding(.top,model.topPadding)
                    .sheet(isPresented: $model.showImportSheet) {
                        importSheet
                    }.sheet(isPresented: $model.showImportSettingsSheet) {
                        model.showImportSettingsSheet = false
                    } content: {
                        importSettingsSheet
                    }.hidden(model.shouldHide(size: fullView.size))
                       
                    
                }.onAppear{
                    
                    model.isPortrait = fullView.size.height > fullView.size.width
                    AppLog.write("body",fullView.size,model.leftPaneWidth,fullView.size.width - model.leftPaneWidth)
                    AppLog.write("body:ui",UIScreen.main.bounds)
                    AppLog.write("body:portrait",model.isPortrait)
                    
                    
                }
            }
           
        }
        .background(model.backgroundColor)
        .statusBar(hidden: model.isFullScreen)
        .ignoresSafeArea(model.isFullScreen ? .all : .init())
        
        .onAppear(){
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
            
            if UIDevice.current.userInterfaceIdiom == .phone{
                model.leftPaneWidth = 0
            }
            
            model.appPlayState.restorePlayState()
            
            AppSettings.checkIsPro()
            let countryCode = Locale.current.identifier
            let instOn = AppSettings.createInstalledOn()
            RemoteLogging.log(item: "onAppear: installed on " + instOn + " country " + countryCode)
           
            
        }.onRotate { newOrientation in
            if newOrientation == UIDeviceOrientation.unknown{
                return
            }
            if newOrientation == UIDeviceOrientation.portrait || newOrientation==UIDeviceOrientation.portraitUpsideDown{
                model.isPortrait = true
                //reverse logic
                if UIScreen.main.bounds.height < 850 && model.statusHidden{
                    model.leftPaneWidth = 0
                }
            }else{
                model.isPortrait = false
            }
            AppLog.write("body:rotate:portrait",model.isPortrait)
            
             
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
                    
                    onCameraSelected(camera: aps.camera!,isCameraTap: false)
                }
                
            }else if disco.networkUnavailable || hasCameras() == false {
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
            
            camerasView.netStream.abort = true
            
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
                model.appPlayState.mode = multicamView.multicamView.model.mode
                if let smc = multicamView.selectedCamera(){
                    model.appPlayState.selectedMulticam = smc.getStringUid()
                }
                model.appPlayState.save()
                //other appPlayState should already be set
                
                model.statusHidden = false
                model.mainTabIndex = 0
                model.selectedCameraTab = CameraTab.live
                model.status = ""
                //model.makeLeftPanVisible()
            }
            
            
            
            nxvproApp.stopZeroConfig()

            FileHelper.checkStorageLimits()
        }
        
    }
    
    private func checkAndEnableMulticam(){
        
        /*
        DispatchQueue.main.async{
            var nAuth = 0
            var nFavs = 0
            var allCams = getAllCameras(cameras: cameras.cameras)
            for cam in allCams {
                
                if cam.isAuthenticated() || cam.isNetworkStream() {
                    if cam.isFavorite{
                        nFavs += 1
                    }
                    
                }
            }
            
            //AppLog.write("checkAndEnableMulticam",nFavs)
            
            cameras.cameraGroups.populateCameras(cameras: allCams)
            camerasView.enableMulticams(enable: nFavs > 1)
        }
         */
        
        DispatchQueue.main.async{
           
            let authCams = CameraUtils.getAuthenticatedFavsCount(cameras: cameras.cameras, netStreams: camerasView.netStream.cameras)
            let nFavs = authCams.count
            
            camerasView.enableMulticams(enable: nFavs > 1)
            GroupHeaderFactory.checkAndEnablePlay()
        }
    }
    //MARK: Digital Zoom
    func resetDigitalZoom() {
        player.zoomState.resetZoom()
    }
    //MARK: Enable/Disable toggle sidebar
    func toggleSidebarDisabled(disabled: Bool){
        model.toggleDisabled = disabled
        model.titlebarHeight = disabled ? 0.0 : model.defaultTilebarHeight
    }
    //MARK: FullScreen
    func onToggleFullScreen(){
        model.setFullScreen(fs: !model.isFullScreen)
        multicamView.setFullScreen(isFullScreen: model.isFullScreen)
        if model.isFullScreen && model.leftPaneWidth != 0{
            model.leftPaneWidth = 0
        }
    }
    func isFullScreen()->Bool{
        return model.isFullScreen
    }
    func onMulticamModeChanged(_ newMode: Multicam.Mode) {
        if model.appPlayState.active{
            model.appPlayState.mode = newMode
            model.appPlayState.save()
        }
    }
    func onGlobalAudioMute(muted: Bool) {
        //delegate to either single or multicam view
        if model.multicamsHidden{
            player.toolbar.onGlobalMuteChanged(muted: muted)
            if let cam = model.mainCamera{
                let mutePlayer = muted || cam.muted ? true : false
                player.thePlayer.setMuted(muted: mutePlayer)
            }
        }else{
            multicamView.onGlobalMuteChanged(muted: muted)
        }
    }
    //MARK: Reset camera login
    func resetCamera(camera: Camera) {
        camera.user=""
        camera.password=""
        camera.save()
        
        if let mc = model.mainCamera{
            if mc.sameAs(camera: camera){
                stopPlaybackIfRequired()
                model.status = "Camera reset"
                model.statusHidden = false
                model.showNetworkUnavailble = false
                model.selectedCameraTab = .none
                model.mainTabIndex = 0
            }
            
        }
        
        //force a general refresh
        DiscoCameraViewFactory.handleCameraChange(camera: camera)
    }
    //MARK: Delete camera
    func deleteCamera(camera: Camera) {
        
        let dq  = DispatchQueue(label: "delete_cam")
        dq.async{
            FileHelper.deleteCamera(camera: camera)
            DispatchQueue.main.async{
                
                DiscoCameraViewFactory.reset()
                
                camerasView.netStream.remove(camera: camera)
                cameras.removeCamera(camera: camera)
                cameras.cameraGroups.updateAllCamerasGroup(cameras: getAllCameras(cameras: cameras.cameras))
                groupsView.touch()
                
                if model.mainCamera != nil{
                    if model.mainCamera!.getBaseFileName() == camera.getBaseFileName(){
                        stopPlaybackIfRequired()
                        model.status = "Camera removed"
                        model.statusHidden = false
                        model.showNetworkUnavailble = false
                        model.selectedCameraTab = .none
                        model.mainTabIndex = 0
                    }
                }
            }
        }
    }
    func onSearchFocusChanged(focused: Bool){
        if ProcessInfo.processInfo.isiOSAppOnMac == false{
            model.searchHasFocus = focused
        }
    }
    //MARK: CameraChanged impl
    func onCameraChanged() {
        //enable / disable multicam button
        AppLog.write("NxvProContentView:onCameraChanged")
        DispatchQueue.main.async{
            checkAndEnableMulticam()
        }
    }
    func getSrc() -> String {
        return "mainVc"
    }
    //MARK: GroupChangeListener
    func moveCameraToGroup(camera: Camera, grpName: String) -> [String] {
        AppLog.write("moveCameraToGroup",camera.getDisplayAddr(),grpName)
        
        cameras.cameraGroups.addCameraToGroup(camera: camera, grpName: grpName)
        let names = cameras.cameraGroups.getNames()
        
        DispatchQueue.main.async{
            //groups will have been reloaded from JSON so repopulate the camera objects
            let allCams = getAllCameras(cameras: cameras.cameras)
            cameras.cameraGroups.populateCameras(cameras: allCams)
            GroupHeaderFactory.reset()
            groupsView.touch()
            camerasView.touch()
            globalLocationView.setAllCameras(allCameras: allCams)
            
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
    func reconnectToCamera(camera: Camera, delayFor: Double) {
       
            if model.multicamsHidden == false{
                multicamView.multicamView.reconnectToCamera(camera: camera,delayFor: delayFor)
            }else{
                if let mcam = model.mainCamera{
                    if mcam.sameAs(camera: camera){
                        
                        AppLog.write("MainVc:reconnectToCamera delayFor",delayFor,mcam.getStringUid())
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delayFor){
                            model.status = "Reconnecting to " + camera.getDisplayName() + "...";
                            reconnectToCamera(camera: camera)
                        }
                    }
                }
            }
       
    }
    
    func onIsAlive(camera: Camera) {
        
    }
    private func initCameraTabs(camera: Camera){
        cameraTabHeader.setCurrrent(camera: camera)
        deviceInfoView.setCamera(camera: camera, cameras: cameras, listener: self)
        storageView.setCamera(camera: camera)
        let allCams = getAllCameras(cameras: cameras.cameras)
        locationView.setCamera(camera: camera, allCameras: allCams, isGlobalMap: false)
        systemView.setCamera(camera: camera)
        systemLogView.setCamera(camera: camera)
        
    }
    func reconnectToCamera(camera: Camera) {
        RemoteLogging.log(item: "reconnectToCamera "+camera.getStringUid())
        stopPlaybackIfRequired()
        onCameraSelected(camera: camera, isCameraTap: false)
    }
    func onPlayerReady(camera: Camera) {
        DispatchQueue.main.async {
            model.statusHidden = true
            
            initCameraTabs(camera: camera)
            model.selectedCameraTab = .live
            model.tabSelected(tabIndex: .live)
            
            //make sure the profile selector is enabled
            DiscoCameraViewFactory.setCameraSelected(camera: camera)
            DiscoCameraViewFactory.handleCameraChange(camera: camera, isAuthChange: true)
            player.showToolbar()
            
            model.appPlayState.reset()
            model.appPlayState.camera = camera
            model.appPlayState.active = true
            model.appPlayState.save()
            model.clonePlayState()
            
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
            
            RemoteLogging.log(item: "onPlayerReady "+camera.getStringUid() + " " + camera.name)
        }
        
    }
    
    func onBufferring(camera: Camera, pcent: String) {
        DispatchQueue.main.async{
            if let cam = model.mainCamera{
                if cam.sameAs(camera: camera){
                    model.status = pcent
                }
            }
        }
    
    }
    func onMotionEvent(camera: Camera,start: Bool,isActive: Bool){
        player.motionDetectionLabel.setActive(isStart: start)
        multicamView.onMotionEvent(camera: camera, start: start)
        if start{
            Helpers.playAudioAlert()
        }
    }
    //MARK: Object rec confidence changed
    func onObjectConfidenceLevelChanged(camera: Camera){
        player.onObjectConfidenceLevelChanged(camera: camera)
        multicamView.onObjectConfidenceLevelChanged(camera: camera)
        storageView.onDeviceView.onObjectConfidenceLevelChanged(camera: camera)
        
        
    }
    func onSnapshotChanged(camera: Camera) {
      
        DispatchQueue.main.async{
             
             DiscoCameraViewFactory.handleThumbChanged(camera)
         }
    }
    
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async{
            model.status = error
            
            if model.selectedCameraTab == CameraTab.live{
                model.statusHidden = false
            }
            
            if camera.isAuthenticated(){
                let waitTime = player.thePlayer.playerView.getRetryWaitTime()
                
                if model.multicamsHidden{
                    model.status = error + "\nAttempting reconnect..."
                }
                reconnectToCamera(camera: camera, delayFor: waitTime)
                
                if model.isFullScreen && player.thePlayer.playerView.reconnectTries > 1{
                    model.setFullScreen(fs: false)
                }
            }
        }
        
        RemoteLogging.log(item: "NxvProContentView:onError "+error)
    }
    
    func connectAuthFailed(camera: Camera) {
        
    }
    func onRecordingEnded(camera: Camera){
        storageView.touchOnDevice()
        DispatchQueue.main.async {
            storageView.onDeviceView.refresh()
        }
        
    }
    func onRecordingTerminated(camera: Camera, isTimeout: Bool){
        AppLog.write("MainView:onRecordingTerminated")
        
        DispatchQueue.main.async{
            
            if model.multicamsHidden{
                player.onRecordingTerminated()
             
                onRecordingEnded(camera: camera)
                
                if AppSettings.IS_PRO && isTimeout{
                    
                    let exceeded = FileHelper.hasExceededMediaLimit()
                    if !exceeded{
                        if player.canStartNextRecording(camera){
                            AppLog.write("MainView:onRecordingTerminated -> Starting next chunk")
                            player.toolbar.onRecordingStarted();
                        }
                        
                    }
                    
                }
            }
        }
    }
    
    func autoSelectCamera(camera: Camera) {
        //no used here but in multicam view
    }
    
    //MARK: CameraEventListener
    
    func onCameraSelected(camera: Camera,isCameraTap: Bool){
        
        //disable any imported camera with ANPR on
        camera.anprOn = false
        
        //clear flag so we don't show left pane for iPhone
        model.discoFirstTime = false
        
        if model.multicamsHidden == false{
            stopMulticams()
        }else{
            player.hideControls()
            stopPlaybackIfRequired()
        }
        model.mainCamera = nil
        model.appPlayState.reset()
        model.selectedCameraTab = .live
        groupsView.model.selectedCamera = camera
        camerasView.model.selectedCamera = camera
        model.selectedCameraTab = .none
        
        let muted = AppSettings.isGlobalAudioMuted()
        player.toolbar.onGlobalMuteChanged(muted: muted)
        
        if camera.isAuthenticated()==false{
            loginDlg.setCamera(camera: camera, listener: self)
            model.showLoginSheet = true
        }else{
             
            if camera.isNvr(){
                if model.isPortrait{//UIDevice.current.userInterfaceIdiom == .phone{
                    model.leftPaneWidth = 0
                }
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
            
            AppLog.write("NxvProContentView:onCameraSelected orientation",model.isPortrait)
            
            if model.isPortrait{//UIDevice.current.userInterfaceIdiom == .phone{
                model.leftPaneWidth = 0
                
            }
            
            model.status = "Connecting to " + camera.getDisplayName() + "..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
                
                player.setCamera(camera: camera, listener: self,eventListener: self)
                
            })
        }
    }
    func onMulticamReconnectAll(group: CameraGroup) {
        debugPrint("MVC:onMulticamReconnectAll",group.name)
        if model.multicamsHidden == false{
            var isSameGroup = false
            let aps = model.appPlayState
            if let grp = aps.group{
                isSameGroup = grp.id == group.id
            }else if group.id == CameraGroup.ALL_CAMS_ID{
                isSameGroup = true
            }
            
            if isSameGroup{
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    multicamView.resumeAll()
                }
            }
        }
    }
    func openGroupMulticams(group: CameraGroup){
        //clear flag so we don't show left pane for iPhone
        model.discoFirstTime = false
        
        if model.multicamsHidden == false{
            stopMulticams()
            model.statusHidden = false
            //model.status = defaultStatusLabel
            showSelectCamera()
            
        }else{
            
            stopPlaybackIfRequired()
            
            if let lrm = group.lowResMode{
                Camera.isMulticamLowRes = lrm
            }
            
            camerasView.enableMulticams(enable: false)
            camerasView.setMulticamActive(active: true)
            GroupHeaderFactory.disableNotPlaying()
            
            //prepare for a resume
            model.appPlayState.reset()
            model.appPlayState.isMulticam = true
            model.appPlayState.group = group
            model.appPlayState.multicams = nil
            model.appPlayState.save()
            
            if model.isPortrait{//UIDevice.current.userInterfaceIdiom == .phone{
                model.leftPaneWidth = 0
            }
            
            DispatchQueue.main.async{
                var favs = [Camera]()
                if group.isNvr{
                    if group.cameras.count > 0{
                        let nvr = group.cameras[0]
                        let vcams = nvr.vcams
                        for cam in vcams{
                            if cam.isFavorite{
                                favs.append(cam)
                            }
                        }
                    }
                }else{
                    let allCams = getAllCameras(cameras: cameras.cameras)
                    
                    for cam in allCams{
                        if group.includesCamera(camera: cam) || group.id == CameraGroup.ALL_CAMS_ID{
                            if cam.isNvr(){
                                let vcams = cam.vcams
                                for cam in vcams{
                                    if cam.isFavorite{
                                        favs.append(cam)
                                    }
                                }
                            }else if cam.isFavorite{
                                
                                favs.append(cam)
                            }
                        }
                           
                    }
                }
                
                favs.sort(by: {$0.displayOrder<$1.displayOrder})
                model.appPlayState.multicams  = favs
                model.appPlayState.active = true
                model.appPlayState.save()
                
                self.model.multicamsHidden = false
                self.multicamView.setCameras(cameras: favs,title: group.name)
                self.multicamView.playAll()
                
                
                if model.leftPaneWidth > 0 {
                    toggleSideBar()
                }
            }
        }
        
    }
    func onMulticamsStopped() {
            
    }
    func onRetryShowMulticams(cameras: [Camera]) {
        //not implemented
    }
    func onShowMulticams(){
        //clear flag so we don't show left pane for iPhone
        model.discoFirstTime = false
        if model.multicamsHidden{
            let favs = getAuthenticatedFavs()
            if favs.count > 1 {
                camerasView.disableMove()
                stopPlaybackIfRequired()
                
                if model.isPhone{
                    model.autoCloseLeftPane()
                }
                
                
                
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
                model.appPlayState.active = true
                model.appPlayState.save()
                
            }else{
                camerasView.enableMulticams(enable: false)
            }
            
        }else{
            stopMulticams()
        }
    }
    func stopMulticams(){
        Camera.isMulticamLowRes = false
        model.selectedCameraTab = CameraTab.none
        multicamView.stopAll()
        model.multicamsHidden = true
        model.showMulticamAlt = false
        model.status = ""
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
        player.hideVmdLabel()
        if model.mainCamera != nil{
            player.stop(camera: model.mainCamera!)
            model.mainCamera = nil
            model.appPlayState.active = false
        }
    }
    func onGroupStateChanged(reload: Bool = false){
        //toggle group expand / collapse
        DispatchQueue.main.async{
            if reload{
                
                cameras.cameraGroups.reset()
                let allCams = CameraUtils.getAllCameras(cameras: cameras.cameras, netStreams: camerasView.netStream.cameras)
                cameras.cameraGroups.populateCameras(cameras: allCams)
            }
            
            groupsView.touch()
            cameraLocationsView.touch()
            
            updateZeroConfigOutput()
        }
    }
    func onShowAddCamera(mode: VideoSource) {
        if mode != .none{
            importSheet.model.autoSelectMode = mode
        }
        model.showImportSheet = true
    }
    func onNetStreamImported() {
        camerasView.netStream.refresh()
    }
    func onWanImportComplete(camera: Camera) {
        //cameras.allCameras.reset()
        DispatchQueue.main.async{
            if cameras.cameras.count == 0{
                cameras.addCamera(camera: camera)
                return
            }
            
            for i in 0...cameras.cameras.count-1{
                if cameras.cameras[i].sameAs(camera: camera){
                    
                    /*
                    cameras.cameras[i].xAddr = camera.xAddr
                    cameras.cameras[i].name = camera.name
                    cameras.cameras[i].user = camera.user
                    cameras.cameras[i].password = camera.password
                    cameras.cameras[i].authenticated  = camera.password.isEmpty == false
                    if cameras.cameras[i].authenticated{
                        cameras.cameras[i].profileIndex = 0
                    }
                    cameras.cameras[i].save()
                    */
                    cameras.cameras[i].loadCredentials()
                     return
                }
            }
            //disco.flushAndRestart()
        }    }
    func onImportConfig(camera: Camera) {
        //show login after added
        model.lastManuallyAddedCamera = camera
        onImportConfigComplete()
    }
    func onImportConfigComplete(){
        AppLog.write("onImportConfigComplete")
        
        disco.cameras.allCameras.loadFromXml()
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
            //self.closeHelpViews()
            model.status = "Camera added"
            disco.start()
        })
        
    }
    func refreshCameras(){
        //need to force a complete refresh here
        model.isImportMode = true
        
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
        if let cam = model.mainCamera{
            if cam.sameAs(camera: camera){
                cameraTabHeader.setCurrrent(camera: camera)
            }
        }
        //this a background update from EENApi
        AppLog.write("MainVc:onCameraNameChanged",camera.getDisplayNameAndAddr())
        groupsView.onCameraChanged()
    }
    
    func loginCancelled() {
        model.showLoginSheet = false
    }
    
    func loginStatus(camera: Camera, success: Bool) {
        if success {
            model.showLoginSheet = false
            cameras.cameraUpdated(camera: camera)
            DiscoCameraViewFactory.handleCameraChange(camera: camera,isAuthChange: true)
            
            
            if camera.isNvr(){
                groupsView.highlightGroupNvr(camera: camera)
                model.mainTabIndex = 1
                mainTabHeader.changeHeader(index: 1)
                if model.isPortrait==false{
                    onCameraSelected(camera: camera, isCameraTap: false)
                }
            }
            else{
                onCameraSelected(camera: camera, isCameraTap: false)
            }
        }
    }
    @State var networkError: Bool = false
    //MARK: NetworkChangedListener
    func onNetworkStateChanged(available: Bool) {
        AppLog.write("onNetworkStateChanged",available)
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
        
        if model.multicamsHidden{
            stopPlaybackIfRequired()
        }else{
            stopMulticams()
        }
        model.mainTabIndex = 0
        model.statusHidden = false
        model.selectedCameraTab = CameraTab.none
        
        if deleteFiles{
            FileHelper.deleteAll()
            eenApi.reset()
            importSheet.eenReset()
        }
        model.status = "Waiting for refresh..."
        
        if deleteFiles{
            camerasView.netStream.reset()
            DiscoCameraViewFactory.reset()
            
            if model.leftPaneWidth == 0{
                toggleSideBar()
            }
        }
        multicamView.clearStorage()
       
        model.statusHidden = false
        model.showNetworkUnavailble = false
        
        disco.flushAndRestart()
        
        if cloudStorage.iCloudAvailable && deleteFiles{
            cloudStorage.deleteAll()
        }
        
        GroupHeaderFactory.reset()
        LocationHeaderFactory.reset()
        cameraLocationsView.touch()
        
        
    }
    //MARK: Manual refesh
    func resetDiscovery() {
        clearStorageImpl(deleteFiles: false)
        
    }
    
    //MARK: DiscoveryListener
    func networkNotAvailabled(error: String) {
        AppLog.write("OnvifDisco:networkNotAvailabled",error)
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
    private func checkAppPlayState(camera: Camera) -> Bool{
        
        if model.appPlayState.isMulticam{
             
            let mcm = model.appPlayState.mode
            
            
            if model.appPlayState.grpName.isEmpty{
                if model.appPlayState.isMulticamReadyToResume(cameras: cameras.cameras){
                    AppLog.write("OnvifDisco:cameraAdded try restore multicam no group")
                    model.appPlayState.reset()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
                        multicamView.multicamView.setRestoreMode(mode: mcm)
                        onShowMulticams()
                        model.status = ""
                    })
                    
                    return true
                }
            }
            else if camera.isAuthenticated() && camera.isNvr(){
                AppLog.write("OnvifDisco:cameraAdded NVR",camera.getDisplayName(),model.appPlayState.grpName)
                if camera.name.hasPrefix(model.appPlayState.grpName) {
                    model.appPlayState.reset()
                    
                    let nhm = NvrHeaderModel(camera: camera)
                    let cg = nhm.vGroup
                    //model.multicamsHidden = true
                    
                    //GroupHeaderFactory.checkAndEnablePlay()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
                        model.status = ""
                        multicamView.multicamView.setRestoreMode(mode: mcm)
                        openGroupMulticams(group: cg)
                        mainTabHeader.changeHeader(index: 1)
                        GroupHeaderFactory.setGroupPlayState(group: cg, playing: true)
                        
                    })
                    
                    return true
                 }
            }
            else if model.appPlayState.isGroupReadyToResume(cameras: cameras.cameras){
                AppLog.write("OnvifDisco:cameraAdded resume last GROUP session",model.appPlayState.grpName)
                model.appPlayState.reset()
                
                if let cg = cameras.cameraGroups.getGroupFor(camera: camera){
                   
                    //GroupHeaderFactory.checkAndEnablePlay()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
                        model.status = ""
                        multicamView.multicamView.setRestoreMode(mode: mcm)
                        openGroupMulticams(group: cg)
                        mainTabHeader.changeHeader(index: 1)
                        GroupHeaderFactory.setGroupPlayState(group: cg, playing: true)
                    })
                    
                    return true
                }
            }
        }else if camera.isAuthenticated() && model.appPlayState.isCameraToResume(camera: camera){
            AppLog.write("OnvifDisco:cameraAdded resume last session",camera.getDisplayName(),camera.getStringUid())
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
                model.appPlayState.reset()
                //model.status = ""
                onCameraSelected(camera: camera, isCameraTap: false)
                if cameras.cameraGroups.isCameraInGroup(camera: camera){
                    //select groups tab
                    mainTabHeader.changeHeader(index: 1)
                }
            })
            
            return true
        }
    
    
        return false
    }
    func cameraAdded(camera: Camera) {
        AppLog.write("OnvifDisco:cameraAdded",camera.getDisplayName())
     
        cameras.cameraGroups.updateAllCamerasGroup(cameras: getAllCameras(cameras: cameras.cameras))
       
        if model.multicamsHidden == false{
            AppLog.write("OnvifDisco:cameraAdded ignored app is playing")
            return
        }
        
        if model.appPlayState.active{
            debugPrint("AppPlayState.active")
            if checkAppPlayState(camera: camera){
                model.leftPaneWidth = model.appPlayState.leftPaneWidth
                
                return
            }
        }
        
        showSelectCamera()
        model.showNetworkUnavailble = false
        model.showBusyIndicator = false
        
        if model.discoFirstTime && model.leftPaneWidth == 0{
            toggleSideBar()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1,execute: {
            checkAndEnableMulticam()
            cameras.cameraGroups.updateAllCamerasGroup(cameras: getAllCameras(cameras: cameras.cameras))
           
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
        AppLog.write("Camera changed->does nothing",camera.getStringUid())
    }
    
    func discoveryError(error: String) {
        AppLog.write("OnvifDisco:discoveryError",error)
    }
    
    func discoveryTimeout() {
        AppLog.write("discoveryTimeout")
        DispatchQueue.main.async {
            model.showBusyIndicator = false
            camerasView.enableRefresh(enable: true)
            
            if model.isImportMode{
                model.isImportMode = false
                
                cameras.allCameras.loadFromXml()
                
                for cam in cameras.cameras{
                    debugPrint("discoTimeout",cam.getDisplayName(),cam.profiles.count)
                    if cam.isAuthenticated(){
                        cam.save()
                        DiscoCameraViewFactory.handleCameraChange(camera: cam,isAuthChange: true)
                    }
                }
                
            }
        }
        let hasCams = getAllCameras(cameras: cameras.cameras).count > 0
        if !hasCams || networkError {
            
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
                if defaultStatusLabel.contains("Connecting")==false && defaultStatusLabel.contains("Buffering")==false{
                    //model.status = cameras.getDiscoveredCount() > 0 ? defaultStatusLabel : ""
                    showSelectCamera()
                }
                model.showNetworkUnavailble = false
                
                if model.discoFirstTime{
                    model.discoFirstTime = false
                    if model.leftPaneWidth == 0{
                        toggleSideBar()
                    }
                }
            }
            if model.discoRefreshRate == 10 {
                if networkError {
                    networkError = false
                }else if(disco.camerasFound == false){
                    model.discoRefreshRate = 15
                }else{
                    if model.showLoginSheet{
                        model.discoRefreshRate = 90
                    }
                    else if model.multicamsHidden == false{
                        model.discoRefreshRate = 120
                    }else if model.mainCamera != nil{
                        model.discoRefreshRate = 90
                    }
                    else{
                        model.discoRefreshRate = 30
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + model.discoRefreshRate) {
                
                camerasView.enableRefresh(enable: false)
                disco.start()
                
            }
        }
        
        DispatchQueue.main.async{
            //only check net stream zombie states when not in MC mode
            if model.multicamsHidden{
                camerasView.netStream.checkForZoombies()
            }
            
            updateZeroConfigOutput()
        }
        
        let nd = disco.numberOfDiscos - 1
        if eenApi.isEnabled() && nd % 5 == 0{
            eenApi.syncWithCloud{ ok in
                AppLog.write("EEN API SYNC WITH CLOUD result",ok)
                if ok && eenApi.getLocalRtpsCont() > 0{
                    self.importSheet.eenRefresh()
                }
            }
        }
    }
    
    private func updateZeroConfigOutput(){
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
            if AppSettings.IS_PRO && AppSettings.sendInstallLog{
                NXVProxy.sendInstallNotifcationIfNew()
            }
            
            debugPrint("FLAT WAN",flatWan)
        }
        
        if camerasView.netStream.cameras.count>0{
            let flatNs = FileHelper.exportNetworkStreams(netStreams: camerasView.netStream.cameras)
            zeroConfigSyncHandler.flatNetStreams = flatNs
          
        }
    }
    
    
    func zombieStateChange(camera: Camera) {
        
    }
    
    //MARK: Camera location list item selected
    func onCameraLocationSelected(camera: Camera){
        if model.isPortrait{
            model.leftPaneWidth = 0
        }
        let allCams = getAllCameras(cameras: cameras.cameras)
        globalLocationView.setCamera(camera: camera, allCameras: allCams)
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
            AppLog.write("RebootDevice resp",xmlPaths)
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
                        if model.leftPaneWidth==0{
                            toggleSideBar()
                        }
                    })
                }
            }
        }
    }
    //MARK: Local storage settings
    func onSettingsUpdated(){
        
    }
    //MARK: Body detect notfication
    func onBodyDetection(camera: Camera,video: URL){
        if UIDevice.current.userInterfaceIdiom == .phone{
            return
        }
        //show overlay image
        //only applies to iPad
        AppLog.write("MainVC:onBodyDetection",camera.getDisplayAddr())
        
        if model.multicamsHidden{
            DispatchQueue.main.async {
                player.showOverlay(video)
            }
        }
    }
   
    //MARK: OSX ONLY STUBS
    func onCameraProfileChanged(camera: Camera) {
     }
    func onCameraSettingsChanged(camera: Camera) {
      }
     func onShowObjectSchedule(camera: Camera) {
      }
    func onObjectScheduleChanged(camera: Camera, isActive: Bool) {
     }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProContentView()
    }
}
