//
//  NxvProMulticamView.swift
//  nxvpro
//
//  Created by Philip Bishop on 16/02/2022.
//

import SwiftUI

class NxvProMulticamModel : ObservableObject{
    @Published var selectedPlayer: CameraStreamingView?
    @Published var selectedCamera: Camera?
    @Published var multicamTitle = "Multicams"
    
    @Published var selectedHeader = "Multicams"
    @Published var segHeaders = ["Multicams","Local storage","Locations"]
    
    @Published var multicamsHidden = false
    @Published var storageHidden = true
    @Published var locationHidden = true
    
    @Published var gridIconHidden: Bool = true
    
    @Published var isFullScreen = false
    @Published var isTvMode = false
    @Published var toolbarToggleOff = false
    @Published var hideSelectCameraTip = false
    
    var currentMode = Multicam.Mode.grid
    
    func onTabChanged(){
        if selectedHeader == segHeaders[0]{
            multicamsHidden = false
            locationHidden = true
            storageHidden = true
        }else if selectedHeader == segHeaders[1]{
            multicamsHidden = true
            locationHidden = true
            storageHidden = false
        }else if selectedHeader == segHeaders[2]{
            multicamsHidden = true
            locationHidden = false
            storageHidden = true
        }
    }
    
}

struct NxvProMulticamView: View, MulticamActionListener, CameraToolbarListener, VmdEventListener{
    //MARK: VmdEventListener
    func vmdVideoEnabledChanged(camera: Camera, enabled: Bool) {
        if let thePlayer = mcModel.selectedPlayer{
            thePlayer.playerView.setVmdVideoEnabled(enabled: enabled)
        }
        
    }
    
    func vmdEnabledChanged(camera: Camera, enabled: Bool) {
        if let thePlayer = mcModel.selectedPlayer{
            thePlayer.playerView.setVmdEnabled(enabled: enabled)
        }
        DispatchQueue.main.async {
            //model.vmdLabelHidden = !enabled
            let multicamFactory = multicamView.multicamFactory
            multicamFactory.setVmdOn(camera, isOn: enabled)
        }
        
    }
    
    func vmdSensitivityChanged(camera: Camera, sens: Int) {
        if let thePlayer = mcModel.selectedPlayer{
            thePlayer.playerView.setVmdSensitivity(sens: sens)
        }
    }
    
    func showHelpContext(context: Int) {
        helpView.setContext(contextId: context, listener: model.cameraEventHandler!)
        model.helpHidden = false
    }
    
    func closeVmd() {
        model.vmdCtrlsHidden = true
        model.toolbarHidden = false
        model.helpHidden = true
    }
    
    func onMotionEvent(camera: Camera,start: Bool){
        multicamView.onMotionEvent(camera: camera, start: start)
    }
    
    @ObservedObject var mcModel = NxvProMulticamModel()
    @ObservedObject var model = SingleCameraModel()
    
    let multicamView = MulticamView2()
    
    let toolbar = CameraToolbarView()
    let vmdCtrls = VMDControls()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    
    let storageView =  OnDeviceStorageView()
    let locationView = CameraLocationView()
    
    func setCameras(cameras: [Camera],title: String = "Multicams"){
        toolbar.model.settingsEnabled = false
        multicamView.setCameras(cameras: cameras,listener: self)
        
       var tabName = title
        if tabName.count > 10{
            tabName = Helpers.truncateString(inStr: title, length: 10)
        }
       mcModel.segHeaders[0] = tabName
        
        storageView.setCameras(cameras: cameras)
        locationView.setCamera(camera: cameras[0], allCameras: cameras, isGlobalMap: false)
        
    }
    
    func playAll(){
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            multicamView.playAll()
        })
    }
    func stopAll(){
        model.setIsRecording(false)
        model.hideConrols()
        multicamView.stopAll()
        
    }
    func disableAltMode(){
        multicamView.disableAltMode()
    }
    func selectedCamera() -> Camera?{
        return mcModel.selectedCamera
    }
    func setSelectedCamera(camera: Camera?,isLandscape: Bool){
        
        if let smc = camera{
            multicamView.model.autoSelectCamMode = isLandscape
            multicamView.model.autoSelectMulticam = smc
        }
    }
    
    
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        if let thePlayer = mcModel.selectedPlayer{
            
            if cameraEvent == .bodyDetection{
                if let cam = mcModel.selectedCamera{
                    cam.vmdOn = !cam.vmdOn
                    cam.vmdMode = cam.vmdOn ? 1 : 0
                    cam.save()
                    vmdEnabledChanged(camera: cam, enabled: cam.vmdOn)
                    //need to set vmd controls to disabled
                    vmdCtrls.model.vmdEnabled = false
                }
            }
            
            model.cameraEventHandler?.itemSelected(cameraEvent: cameraEvent, thePlayer: thePlayer)
            
            if cameraEvent == .Record{
                if let cam = mcModel.selectedCamera{
                    multicamView.toggleRecordingState(camera: cam)
                }
            }
        }
    }
    //MARK: MulticamActionListener
    func multicamModeChanged(mode: Multicam.Mode){
        globalCameraEventListener?.onMulticamModeChanged(mode)
    }
    func multicamSelected(camera: Camera, mcPlayer: CameraStreamingView) {
        mcModel.selectedPlayer = mcPlayer
        mcModel.selectedCamera = camera
        mcModel.isTvMode = multicamView.isTvMode()
        if multicamView.isPlayerReady(cam: camera) == false{
            return
        }
        
        
        model.hideConrols()
        model.theCamera = camera
        //model.cameraEventListener = eventListener
        toolbar.setCamera(camera: camera)
        if mcPlayer.playerView.isRecording{
            model.setIsRecording(true)
            toolbar.setRecordStartTime(startTime: mcPlayer.playerView.recordStartTime)
        }else{
            model.setIsRecording(false)
        }
        
        vmdCtrls.setCamera(camera: camera, listener: self)
        mcPlayer.playerView.motionListener = vmdCtrls
        
        model.cameraEventHandler = CameraEventHandler(model: model,toolbar: toolbar,ptzControls: ptzControls,settingsView: settingsView,helpView: helpView,presetsView: presetsView,imagingCtrls: imagingCtrls)
        
        if let handler = model.cameraEventHandler{
            
            ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: handler)
            
            handler.getPresets(cam: camera)
            handler.getImaging(camera: camera)
        }
        
        model.toolbarHidden = false
        
        let isOn = multicamView.isAltMode()
        mcModel.gridIconHidden = isOn == false
        globalCameraEventListener?.multicamAltModeOn(isOn: isOn)
        
        locationView.changeCamera(camera: camera)
    }
    
    func clearStorage(){
        locationView.resetMap()
    }
    
    func setFullScreen(isFullScreen: Bool){
        mcModel.isFullScreen = isFullScreen
    }
    private func cameraToolbarOptsFS() -> some View{
        ZStack(alignment: mcModel.isTvMode ? .topTrailing : .bottomTrailing){
            HStack{
                Spacer()
                let left =  10.0
                let edges = EdgeInsets(top: 10, leading: left, bottom: 10, trailing: 10)
                let rounded = 5.0
                
                multicamModeToolbar(btnSize: CGFloat(12))
                    .padding(edges)
                    .background(AppIconModel.controlBackgroundColor())
                    .cornerRadius(rounded)
                
            }.padding(mcModel.isTvMode ? .top :.bottom)
                .hidden(model.toolbarHidden && model.ptzCtrlsHidden && model.vmdCtrlsHidden)
        }
    }
    private func cameraToolbarLabel() -> some View{
       
        HStack{
            CameraToolbarLabel(label: model.getCameraName())
    
        }.padding(.bottom,58)
            .hidden(model.toolbarHidden && model.ptzCtrlsHidden && model.vmdCtrlsHidden)
        
    }
    //MARK: Expermintal onRotate
    private func onOrientationChanged(isPortrait: Bool){
        guard UIDevice.current.userInterfaceIdiom == .pad else{
            return
        }
        guard multicamView.hasCameras() else{
            return
        }
        guard !isPortrait else {
            return
        }
        let dq = DispatchQueue(label: "mcvlc")
        dq.asyncAfter(deadline: .now() + 0.5){
            self.reselectCam()
        }
    }
    private func reselectCam(){
        DispatchQueue.main.async{
            model.toolbarHidden = true
           //need to reselect the main cam if exist
            if let lastSelected = multicamView.getLastSelectedCamera(){
                debugPrint("onOrientationChanged lastSelected",lastSelected.getDisplayName())
                multicamView.camSelected(cam: lastSelected,isLandscape: true)
            }
            
        }
    }
    var tabHeight = CGFloat(32.0)
    func multicamModeToolbar(btnSize: CGFloat = 20.0) -> some View{
        HStack(spacing: 25){
            if AppSettings.IS_PRO && multicamView.canShowTvButton(){
                //rectangle.center.inset.filled
                Button(action: {
                    DispatchQueue.main.async{
                        mcModel.gridIconHidden=false
                        multicamView.changeAltMode(.tv)
                        //globalCameraEventListener?.hideSideBar()
                    }
                }){
                    Image(systemName: "play.tv").resizable()
                        .frame(width: btnSize,height: btnSize)
                }
            }
            if multicamView.canShowGridButton(){
                Button(action: {
                    globalCameraEventListener?.multicamAltModeOff()
                    mcModel.isTvMode = false
                    mcModel.currentMode = .grid
                    multicamView.setRestoreMode(.grid)
                    mcModel.toolbarToggleOff = false
                    multicamView.clearAltSelected()
                    mcModel.gridIconHidden = true
                }){
                    Image(systemName: "square.grid.2x2").resizable()
                        .frame(width: btnSize,height: btnSize)
                    
                }
                
            }
            if multicamView.canShowAltButton(){
                Button(action: {
                    DispatchQueue.main.async{
                        mcModel.gridIconHidden = false
                        multicamView.changeAltMode(.alt)
                        
                    }
                }){
                    Image(systemName: "rectangle.inset.topleft.filled").resizable()
                        .frame(width: btnSize,height: btnSize)
                }
            }
           
            //if AppSettings.IS_PRO && mcModel.toolbarToggleOff==false{
            if model.toolbarHidden == false{
                hideToolbarView(btnSize: btnSize)
            }
        }
        .opacity(0.75)
        .buttonStyle(.plain)
        .padding(.trailing)

    }
    func hideToolbarView(btnSize: Double) -> some View{
        Button {
            model.toolbarHidden = true
            //mcModel.toolbarToggleOff = !mcModel.toolbarToggleOff
        } label: {
            Image(systemName: "rectangle.slash.fill").resizable()
                .frame(width: btnSize + 3,height: btnSize)
        }
    }
    @State private var orientation = UIDeviceOrientation.unknown
 
    var body: some View {
        GeometryReader { fullView in
            let isPortrait = fullView.size.height > fullView.size.width
            ZStack{
                Color(uiColor: .secondarySystemBackground)
                VStack(spacing: 0){
                    if mcModel.isFullScreen == false{
                        
                        HStack{
                            Picker("", selection: $mcModel.selectedHeader) {
                                ForEach(mcModel.segHeaders, id: \.self) {
                                    Text($0)
                                }
                            }.onChange(of: mcModel.selectedHeader) { tabItem in
                                mcModel.onTabChanged()
                            }.pickerStyle(.segmented)
                                .fixedSize()
                            
                            Spacer()
                            
                            if fullView.size.width > fullView.size.height{
                                multicamModeToolbar()
                                    .hidden(mcModel.multicamsHidden)
                            }
                            
                        }.frame(height: tabHeight)
                    }
                    ZStack{
                        ZStack(alignment: (mcModel.isTvMode && isPortrait==false) ? .top : .bottom){
                            multicamView
                            if mcModel.selectedPlayer != nil{
                                
                                cameraToolbarLabel()
                                
                                //show top right change mode toolbar if full screen
                                if mcModel.isFullScreen{
                                    cameraToolbarOptsFS()
                                }
                            }
                            toolbar.hidden(model.toolbarHidden)
                            ptzControls.hidden(model.ptzCtrlsHidden)
                            vmdCtrls.hidden(model.vmdCtrlsHidden)
                            
                            VStack{
                                
                                Spacer()
                                HStack{
                                    Spacer()
                                    ZStack{
                                        helpView.hidden(model.helpHidden)
                                        settingsView.hidden(model.settingsHidden)
                                        presetsView.hidden(model.presetsHidden)
                                    }
                                }
                                Spacer()
                                
                            }
                            HStack{
                                VStack{
                                    Spacer()
                                    imagingCtrls.padding()
                                    Spacer()
                                }//.padding()
                                Spacer()
                            }.hidden(model.imagingHidden)
                            
                        }
                        
                        ZStack{
                            Color(uiColor: .secondarySystemBackground)
                            storageView
                            
                        }
                        .hidden(mcModel.storageHidden)
                        
                        ZStack{
                            Color(uiColor: .secondarySystemBackground)
                            //Text("Location place holder")
                            locationView
                        }
                        .hidden(mcModel.locationHidden)
                    }
                }
            }
        }
        .onRotate { newOrientation in
            orientation = newOrientation
            onOrientationChanged(isPortrait: orientation.isPortrait)
            AppLog.write("MulticamView:onRotated isPortrait",orientation.isPortrait)
            
        }
        .onAppear{
            toolbar.setListener(listener: self)
            settingsView.model.listener = self
            
        }
    }
}

struct NxvProMulticamView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProMulticamView()
    }
}
