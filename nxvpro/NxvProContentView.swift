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
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}


struct NXTabHeaderView: View {
    
    var tabHeight = CGFloat(32.0)
    
    @State var camTab = NXTabItem(name: "Cameras",selected: true)
    @State var grpsTab = NXTabItem(name: "Groups")
    @State var mapTab = NXTabItem(name: "Map")
    
    private func tabSelected(tabIndex: Int){
        camTab.model.setSelected(selected: tabIndex==0)
        grpsTab.model.setSelected(selected: tabIndex==1)
        mapTab.model.setSelected(selected: tabIndex==2)
    }
    
    var body: some View {
        
        HStack(spacing: 7){
           
            //tab view
           
            camTab.padding(.leading).onTapGesture {
                tabSelected(tabIndex: 0)
            }
    
            grpsTab.onTapGesture {
                tabSelected(tabIndex: 1)
            }
            
            mapTab.onTapGesture {
                tabSelected(tabIndex: 2)
            }
            
            Spacer()
        }.frame(height: tabHeight)
    }
}

protocol CameraEventListener : CameraLoginListener{
    func onCameraSelected(camera: Camera,isMulticamView: Bool)
}

class NxvProContentViewModel : ObservableObject{
    
    @Published var leftPaneWidth = CGFloat(275.0)
    @Published var status = "Searching for cameras..."
    @Published var networkUnavailbleStr = "Check WIFI connection\nCheck Local Network Privacy settings"
    @Published var showNetworkUnavailble: Bool = false
    @Published var showBusyIndicator = false
    @Published var showLoginSheet: Bool = false
    @Published var statusHidden = true

    var discoRefreshRate = 10.0
}

struct NxvProContentView: View, DiscoveryListener,NetworkStateChangedListener,CameraEventListener,VLCPlayerReady {
    
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var model = NxvProContentViewModel()
    @ObservedObject var network = NetworkMonitor.shared
    
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var cameras: DiscoveredCameras
    
    var titlebarHeight = 32.0
    @State var footHeight = CGFloat(85)
    
    var camerasView: NxvProCamerasView
    let loginDlg = CameraLoginSheet()
    let player = CameraStreamingView()
    
    let disco = OnvifDisco()
    init(){
        camerasView = NxvProCamerasView(cameras: disco.cameras)
        cameras = disco.cameras
        disco.addListener(listener: self)
        DiscoCameraViewFactory.tileWidth = CGFloat(model.leftPaneWidth)
        DiscoCameraViewFactory.tileHeight = footHeight
    }
    var body: some View {
        GeometryReader { fullView in
            let rightPaneWidth = fullView.size.width - model.leftPaneWidth
            let vheight = fullView.size.height - titlebarHeight
            VStack{
                HStack{
                    
                    Button(action:{
                        if model.leftPaneWidth == 0{
                            model.leftPaneWidth = CGFloat(275.0)
                        }else{
                            model.leftPaneWidth = 0
                        }
                    }){
                        Image(systemName: "sidebar.left")
                    }.padding(.leading)
                 Spacer()
                    Text("NX-V PRO").fontWeight(.medium)
                        .appFont(.titleBar)
                    Spacer()
                    
                }.frame(width: fullView.size.width,height: titlebarHeight)
                
                HStack(){
                    VStack(alignment: .leading,spacing: 0){
                        
                        NXTabHeaderView()
                        
                        //Selected Tab Lists go here
                        //NxvProCamerasView(cameras: cameras).padding(.leading)
                        //Spacer()
                        
                        camerasView
                    }.sheet(isPresented: $model.showLoginSheet){
                        loginDlg
                    }
                    .hidden(model.leftPaneWidth == 0)
                    .frame(width: model.leftPaneWidth,height: vheight)
                    
                    
                    
                        
                   
                    
                    
                   
                   ZStack{
                        Color(UIColor.secondarySystemBackground)
                       
                       player.hidden(model.showLoginSheet)
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
                    }
                    
                
                 
                    //Spacer()
                }
            }
        }.onAppear(){
            network.listener = self
            camerasView.setListener(listener: self)
            model.statusHidden = false
            model.showBusyIndicator = true
            disco.start()
            
        }.onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            RemoteLogging.log(item: "willEnterForegroundNotification")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            RemoteLogging.log(item: "willResignActiveNotification")
        }
    }
    
    //MARK: VlcPlayerReady
    func onPlayerReady(camera: Camera) {
        DispatchQueue.main.async {
             model.statusHidden = true
            
        }
    }
    
    func onBufferring(camera: Camera, pcent: String) {
        DispatchQueue.main.async{
            model.status = pcent
        }
    }
    
    func onSnapshotChanged(camera: Camera) {
        
    }
    
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async{
            model.status = error
            model.statusHidden = false
        }
    }
    
    func connectAuthFailed(camera: Camera) {
        
    }
    
    func onRecordingTerminated(camera: Camera) {
        
    }
    
    func onIsAlive(camera: Camera) {
        
    }
    
    //MARK: CameraEventListener
    func onCameraSelected(camera: Camera,isMulticamView: Bool){
        if camera.isAuthenticated()==false{
            loginDlg.setCamera(camera: camera, listener: self)
            model.showLoginSheet = true
        }else{
            model.status = "Connecting to " + camera.getDisplayName() + "..."
            model.statusHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
                player.setCamera(camera: camera, listener: self)
            })
        }
    }
    func loginCancelled() {
        model.showLoginSheet = false
    }
    
    func loginStatus(camera: Camera, success: Bool) {
        if success {
            model.showLoginSheet = false
            cameras.cameraUpdated(camera: camera)
        }
    }
    @State var networkError: Bool = false
    //MARK: NetworkChangedListener
    func onNetworkStateChanged(available: Bool) {
        print("onNetworkStateChanged",available)
        networkError = !available
    }
    //MARK: DiscoveryListener
    func cameraAdded(camera: Camera) {
        print("OnvifDisco:cameraAdded",camera.getDisplayName())
    }
    
    func cameraChanged(camera: Camera) {
        
    }
    
    func discoveryError(error: String) {
        print("OnvifDisco:discoveryError",error)
    }
    
    func discoveryTimeout() {
        AppLog.write("discoveryTimeout")
        DispatchQueue.main.async {
            model.showBusyIndicator = false
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
                model.status = cameras.getDiscoveredCount() > 0 ? "Select camera" : "No cameras found"
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
                
                disco.start()
                
            }
        }
    }
    
    func networkNotAvailabled(error: String) {
        print("OnvifDisco:networkNotAvailabled",error)
    }
    
    func zombieStateChange(camera: Camera) {
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProContentView()
    }
}
