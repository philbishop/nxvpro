//
//  MulticamView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 03/07/2021.
//

import SwiftUI

protocol MulticamActionListener{
    func multicamSelected(camera: Camera,mcPlayer: CameraStreamingView)
    func multicamModeChanged(mode: Multicam.Mode)
}

class Multicam{
    enum Mode{
        case grid, alt, tv, none
    }
}

class MulticamViewModel : ObservableObject {
    @Published var cameras = [Camera]()
    @Published var row1 = [Camera]()
    @Published var row2 = [Camera]()
    @Published var row3 = [Camera]()
    
    //@Published var altCamMode: Bool
    @Published var mode = Multicam.Mode.grid
    @Published var autoSelectMulticam: Camera?
    @Published var autoSelectCamMode = false
    
    var listener: MulticamActionListener?
    var lastSelectedCamera: Camera?
    
    var restoreMode = Multicam.Mode.none
    var lastUsedMode = Multicam.Mode.none
    
    init(){
        row1 = [Camera]()
        row2 = [Camera]()
        row3 = [Camera]()
        mode = .grid
        
    }
    
    func reset(cameras: [Camera]){
        self.cameras = cameras
        row1 = [Camera]()
        row2 = [Camera]()
        row3 = [Camera]()
        mode = .grid
        
    }
    
    func setVerticalAltMainCamera(camera: Camera){
    
        /*
        if row2.contains(camera) {
        
            AppLog.write("Move row 2 camera to row 1 pos 1")
        
            let firstCam = row1[0]
            
            var tmp = [Camera]()
            for cam in cameras {
                if cam.getStringUid() != camera.getStringUid()  && cam.getStringUid() != firstCam.getStringUid(){
                    tmp.append(cam)
                }
            }
            
            row1.removeAll()
            row2.removeAll()
            row3.removeAll()
            
            row1.append(firstCam)
            row1.append(camera)
            
            for cam in tmp {
                row2.append(cam)
            }
            
        }
        */
    }
    func setDefaultLayout(){
        
        if cameras.count > 0 {
            let cam = cameras[0]
            row1.append(cam)
            
        }
        if cameras.count > 1 {
            let cam = cameras[1]
            row1.append(cam)
            
        }
        if cameras.count > 2 {
            let cam = cameras[2]
            row2.append(cam)
            
        }
        if cameras.count > 3 {
            let cam = cameras[3]
            row2.append(cam)
            
        }
    }
    func turnAltCamModeOff(){
        row1.removeAll()
        row2.removeAll()
        row3.removeAll()
        
        mode = .grid
        
        setDefaultLayout()
    }
    func setAltMainCamera(camera: Camera,newMode: Multicam.Mode){
        
        
        if newMode == .grid{
            turnAltCamModeOff()
            return
        }
    
        lastSelectedCamera = camera
        
        if newMode == .tv{
            setTvLayout(camera: camera)
            return
        }
        
        row1.removeAll()
        row2.removeAll()
        row3.removeAll()
        
        mode = .alt
        
        row1.append(camera)
        
        var tmp = [Camera]()
        for cam in cameras {
            if cam.getStringUid() != camera.getStringUid() {
                tmp.append(cam)
            }
        }
        
         
        for cam in tmp {
            if row2.count < 3 {
                row2.append(cam)
                
            }else{
                row3.append(cam)
            
            }
        }
        
        AppLog.write(">>setAltMainCamera",camera.getDisplayNameAndAddr(),row1.count,row2.count,row3.count)
        AppLog.write("<<setAltMainCamera")
        
    }
    func setTvLayout(camera: Camera){
        row1.removeAll()
        row2.removeAll()
        row3.removeAll()
        
        mode = .tv
        
        row1.append(camera)
        for cam in cameras {
            if cam.getStringUid() != camera.getStringUid() {
                row2.append(cam)
            }
        }
        AppLog.write(">>setTvLayout",cameras.count,row1.count,row2.count,row3.count)
        AppLog.write("<<setTvLayout")
    }
    //need to pass in CGSize to determine if portrait
    func getWidthForCol(camera: Camera,fullWidth: CGSize,camsPerRow: Int,mode: Multicam.Mode,mainCam: Camera?) -> CGFloat {
        let isPortrait = fullWidth.height > fullWidth.width
        let altMode = mode == .alt
        if altMode && mainCam != nil && mainCam!.getStringUid() == camera.getStringUid() {
            if isPortrait{
                return fullWidth.width
            }
            return fullWidth.width * CGFloat(0.75)
        }
        
        if altMode{
            if isPortrait{
                for cam in row2 {
                    if cam.getStringUid() == camera.getStringUid(){
                        
                        return fullWidth.width * CGFloat(0.33)
                    }
                }
                if row3.count < 3{
                   
                    return fullWidth.width * CGFloat(0.33)
                }
            }
            
            return fullWidth.width * CGFloat(0.25)
        }
        
        return (fullWidth.width / CGFloat(camsPerRow))
        
    }
    
}

struct MulticamView2: View , VLCPlayerReady{
    
    //MARK: VLCPlayerReady
    func reconnectToCamera(camera: Camera, delayFor: Double) {
       
            multicamFactory.reconnectToCamera(camera: camera,delayFor: delayFor)
       
    }
    
    func onIsAlive(camera: Camera) {
        
    }
    func onRecordingEnded(camera: Camera) {
        //TO DO
    }
    func reconnectToCamera(camera: Camera) {
        AppLog.write("MulticamView2:reconnectToCamera [no impl]",camera.getStringUid())
    }
    func onPlayerReady(camera: Camera) {
        RemoteLogging.log(item: "onPlayerReady "+camera.getStringUid() + " " + camera.name)
        DispatchQueue.main.async {
            //multicamFactory.playersReady[camera.getStringUid()] = true
            
            if let asmc = model.autoSelectMulticam{
                if asmc.getStringUid() == camera.getStringUid(){
                    camSelected(cam: asmc,isLandscape: model.autoSelectCamMode)
                    model.autoSelectMulticam = nil
                }
            }
        }
    }
    func onRecordingTerminated(camera: Camera, isTimeout: Bool) {
        AppLog.write("MulticamView2:onRecordingTerminated",camera.getStringUid(),camera.name)
    }
    func onBufferring(camera: Camera,pcent: String) {
        DispatchQueue.main.async {
            multicamFactory.updatePlayersReadyStatus(camera, status: pcent);
            
        }
    }
    func connectAuthFailed(camera: Camera){
        onError(camera: camera, error: "Authentication failed")
    }
    func onSnapshotChanged(camera: Camera) {
        //not invoked, handled in MulticamFactory
        AppLog.write("MulticamView2:onSnapshotChanged",camera.getStringUid(),camera.name)
      
    }
    
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async {
            multicamFactory.updatePlayersReadyStatus(camera,status: error)
        }
        
        RemoteLogging.log(item: "onError " + camera.getStringUid() + " " + camera.name + " " + error)
    }
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model = MulticamViewModel()
    @ObservedObject var multicamFactory = MulticamFactory()
    
    @State var selectedMulticam: Camera?
    @State var selectedPlayer: CameraStreamingView?
    
    func isPlayerReady(cam: Camera) -> Bool {
        return multicamFactory.isPlayerReady(cam)
    }
    func getPlayer(camera: Camera) -> MulticamPlayer?{
        if  multicamFactory.hasPlayer(camera: camera){
            return multicamFactory.getPlayer(camera: camera)
        }
        return nil
    }
    func setCameras(cameras: [Camera],listener: MulticamActionListener){
        
        AppLog.write("MulticamView:setCameras",cameras.count)
        model.listener = listener
        model.reset(cameras: cameras)
    }
    func initModels(){
        
        //iconModel.initIcons(isDark: colorScheme == .dark)
        var modeTouse = Multicam.Mode.alt
        
        if model.restoreMode == .tv{
            modeTouse = .tv
        }else if model.restoreMode == .alt{
            modeTouse = .alt
        }else if model.lastUsedMode != .none{
            modeTouse = model.lastUsedMode
        }
        
        if model.cameras.count>0{
            if model.cameras.count > 4 || modeTouse == .tv{
                
                let mcam = model.cameras[0]
                
                multicamFactory.setCameras(cameras: model.cameras)
                selectedMulticam = mcam
                model.setAltMainCamera(camera: mcam,newMode: modeTouse)
                
                multicamFactory.setCameras(cameras: model.cameras)
            }
            else{
                model.setDefaultLayout()
                if model.cameras.count>0{
                    selectedMulticam = model.cameras[0]
                    model.lastSelectedCamera = selectedMulticam
                }
                multicamFactory.setCameras(cameras: model.cameras)
            }
        }
        multicamFactory.delegateListener = self
        
    }
    //MARK: TV mode
    func canShowTvButton() -> Bool{
        if model.cameras.count>multicamFactory.maxTvModeCams{
            return false
        }else{
            return isTvMode() == false
        }
    }
    func canShowAltButton() -> Bool{
        return model.mode != .alt && model.lastSelectedCamera != nil
    }
    func canShowGridButton() -> Bool{
        return model.mode != .grid && model.cameras.count < 5
    }
    func isTvMode() -> Bool{
        return model.mode == .tv
    }
    func isAltMode() -> Bool{
        return model.cameras.count <= 4 && model.mode == .alt
    }
    func hasCameras() -> Bool{
        return model.cameras.count > 0
    }
    func clearAltSelected(){
        model.autoSelectMulticam = nil
    }
    func setRestoreMode(_ rm: Multicam.Mode){
        model.restoreMode = rm
        model.lastUsedMode = rm
    }
    func changeAltMode(_ newMode: Multicam.Mode){
        var cam = model.cameras[0]
        if let mc = model.lastSelectedCamera{
            cam = mc
        }else{
            model.lastSelectedCamera = cam
        }
        selectedMulticam = cam
        model.mode = newMode
        setRestoreMode(newMode)
        model.setAltMainCamera(camera: cam,newMode: newMode)
        
        camSelected(cam: cam,isLandscape: newMode != .grid)
        if let mcp = multicamFactory.getExistingPlayer(camera: cam){
            model.listener?.multicamSelected(camera: cam, mcPlayer: mcp)
        }
        model.listener?.multicamModeChanged(mode: model.mode)
        
    
    }
    
    
    func playAll(){
        multicamFactory.playAll()
        
    }
    func stopAll(){
        multicamFactory.stopAll()
        
    }
    func resumeAll(){
        for cam in model.cameras{
            multicamFactory.forceReconnectToCamera(camera: cam, delayFor: 0.05)
        }
    }
    func onVmdConfidenceChanged(camera: Camera){
        multicamFactory.onVmdConfidenceChanged(camera: camera)
    }
    func onMotionEvent(camera: Camera,start: Bool){
        multicamFactory.onMotionEvent(camera: camera, isStart: start)
    }
    func autoSelectCamera(camera: Camera) {
       
       
    }
    func toggleRecordingState(camera: Camera){
        let recording = multicamFactory.isRecording(camera)
            multicamFactory.setIsRecording(camera,recording: !recording)
        
        
    }
    func toggleBodyOn(_ cam: Camera){
        cam.vmdOn = !cam.vmdOn
        cam.vmdMode = cam.vmdOn ? 1 : 0
        cam.save()
        
        
    }
   
    //Old code called directly
    func startStopRecording(camera: Camera) -> Bool {
        let mcv = multicamFactory.getPlayer(camera: camera)
        let recording = mcv.player.startStopRecording(camera: camera)
        multicamFactory.setIsRecording(camera,recording: recording)
        return recording
    }
    func toggleMute(camera: Camera){
        AppLog.write("MulticamView:toggleMute not implemented")
        //let mcv = multicamFactory.getPlayer(camera: camera)
        //mcv.toggleMute()
        
    }
    func rotateCamera(camera: Camera){
        AppLog.write("MulticamView:rotateCamera not implemented")
        //let mcv = multicamFactory.getPlayer(camera: camera)
       // mcv.rotateNext()
        
    }
    func vmdStateChanged(camera: Camera,enabled: Bool){
        multicamFactory.setVmdOn(camera, isOn: enabled)
        
    }
    func disableAltMode(){
        model.turnAltCamModeOff()
        
        
    }
    func getLastSelectedCamera() -> Camera?{
        return model.lastSelectedCamera
    }
    func camSelected(cam: Camera,isLandscape: Bool = false){
        AppLog.write("MulticamView:camSelected",cam.getStringUid(),cam.name)
        selectedMulticam = cam
        model.lastSelectedCamera = cam
        
        var newMode =  model.mode
        if newMode == .grid{
            newMode = .alt
        }
        
        if isLandscape{
            model.setAltMainCamera(camera: cam,newMode: newMode)
        }else if Camera.IS_NXV_PRO{
           model.setVerticalAltMainCamera(camera: cam)
           
        }
        
        let player = multicamFactory.getPlayer(camera: cam)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25,execute:{
            model.listener?.multicamSelected(camera: cam,mcPlayer: player.player)
        });
    }
    
    func recordingTerminated(camera: Camera){
        AppLog.write("MulticamView:recordingTerminated",camera.getStringUid(),camera.name)
        multicamFactory.setIsRecording(camera, recording: false)
    }
    
    var verticalEnabled = UIDevice.current.userInterfaceIdiom != .pad
    var aspectRatio = AppSettings.aspectRatio
    
    @ObservedObject private var keyboard = KeyboardResponder()
    
    private func tvLayout(size: CGSize) -> some View{
        ZStack(alignment: .topLeading){
            //let smallW = size.width / 6.0
            let wfs = size.width
            
            let mh = wfs * aspectRatio
            let dsh = size.height - mh
            let sh = dsh < 100 ? 100.0 : dsh
            let sw = sh / aspectRatio

            VStack(alignment: .leading,spacing: 0){
                
                ForEach(model.row1, id: \.self) { cam in
                    multicamFactory.getPlayer(camera: cam).onTapGesture {
                        camSelected(cam: cam,isLandscape: true)
                    }
                    .frame(width: wfs,height: mh)
                }
            }
            VStack{
                Spacer()
                ScrollView(.horizontal){
                    HStack{
                        ForEach(model.row2, id: \.self) { cam in
                            multicamFactory.getPlayer(camera: cam).onTapGesture {
                                camSelected(cam: cam,isLandscape: true)
                            }
                            .frame(width: sw,height: sh)
                        }
                    }
                }
            }
        }
    
    }
    private func portraitLayout(wfs: CGFloat) -> some View{
        ScrollViewReader { value in
            let bw = 1.0
            let bc = Color.accentColor
            ScrollView(.vertical){
                VStack(alignment: .leading,spacing: 0){
                    ForEach(model.row1, id: \.self) { cam in
                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                            camSelected(cam: cam)
                            value.scrollTo(cam.id)
                        }
                        .border(cam == selectedMulticam ? bc : Color.clear,width: bw)
                        .id(cam.id)
                        .frame(width: wfs,height: wfs   * aspectRatio)
                    }
                    ForEach(model.row2, id: \.self) { cam in
                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                            camSelected(cam: cam)
                            value.scrollTo(cam.id)
                        }.border(cam == selectedMulticam ? bc : Color.clear,width: bw)
                        .id(cam.id)
                        .frame(width: wfs,height: wfs   * aspectRatio)
                    }
                    ForEach(model.row3, id: \.self) { cam in
                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                            camSelected(cam: cam)
                            value.scrollTo(cam.id)
                        }.border(cam == selectedMulticam ? bc : Color.clear,width: bw)
                        .id(cam.id)
                        .frame(width: wfs,height: wfs   * aspectRatio)
                    }
                }
            }
        
        }
    }

    var body: some View {
        ZStack{
            GeometryReader { fullView in
                let wf = fullView.size
                let wfs = fullView.size.width /// 2 might use for iPhone NXV-PRO
                
                
                if verticalEnabled || wf.height > wf.width {
                   
                    portraitLayout(wfs: wfs)
                    
                }else if model.mode == .tv{
                    tvLayout(size: fullView.size)
                }else{
                    let isAltMode = model.mode == .alt
                    ScrollView(.vertical){
                        VStack(alignment: .leading,spacing: 0){
                            if isAltMode && fullView.size.width > fullView.size.height - keyboard.currentHeight {
                                HStack(alignment: .top,spacing: 0){
                                    ForEach(model.row1, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, mode: model.mode, mainCam: selectedMulticam)
                                        
                                        let vh = vw  * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        // .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                    }
                                    VStack(spacing: 0){
                                        ForEach(model.row2, id: \.self) { cam in
                                            
                                            let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, mode: model.mode, mainCam: selectedMulticam)
                                            
                                            let vh = vw  * aspectRatio
                                            
                                            multicamFactory.getPlayer(camera: cam).onTapGesture {
                                                camSelected(cam: cam,isLandscape: true)
                                            }
                                            //   .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                            .frame(width: vw,height: vh)
                                            
                                        }
                                        // Divider()
                                    }
                                    
                                }
                                HStack(spacing: 0){
                                    ForEach(model.row3, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, mode: model.mode, mainCam: selectedMulticam)
                                        
                                        let vh = vw   * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        //.border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                        
                                    }
                                    //Divider()
                                }
                            }else{
                                HStack{
                                    ForEach(model.row1, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, mode: model.mode, mainCam: selectedMulticam)
                                        
                                        let vh = vw  * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        //.border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                    }
                                    // Divider()
                                }
                                ScrollView(.horizontal){
                                    HStack{
                                        ForEach(model.row2, id: \.self) { cam in
                                            
                                            let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, mode: model.mode, mainCam: selectedMulticam)
                                            
                                            let vh = vw  * aspectRatio
                                            
                                            multicamFactory.getPlayer(camera: cam).onTapGesture {
                                                camSelected(cam: cam,isLandscape: true)
                                            }
                                            //.border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                            .frame(width: vw,height: vh)
                                            
                                        }
                                        //Divider()
                                    }
                                }
                                ScrollView(.horizontal){
                                    
                                    HStack{
                                        ForEach(model.row3, id: \.self) { cam in
                                            
                                            let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, mode: model.mode, mainCam: selectedMulticam)
                                            
                                            let vh = vw  * aspectRatio
                                            
                                            multicamFactory.getPlayer(camera: cam).onTapGesture {
                                                camSelected(cam: cam,isLandscape: true)
                                            }
                                            //.border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                            .frame(width: vw,height: vh)
                                            
                                        }
                                        //Divider()
                                    }
                                }
                            }
                        }
                    }
                    
                
                }
                
            }
            
        }
        .background(Color(iconModel.multicamBackgroundColor))
        
        .onAppear(){
            AppLog.write("MulticamView:onAppear",model.cameras.count)
            
            initModels()
        }
    }
    
    func setRestoreMode(mode: Multicam.Mode){
        model.restoreMode = mode
        initModels()
    }
}
