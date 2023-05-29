//
//  MulticamView.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 03/07/2021.
//

import SwiftUI

protocol MulticamActionListener{
    func multicamSelected(camera: Camera,mcPlayer: CameraStreamingView)
}

class MulticamViewModel : ObservableObject {
    @Published var cameras = [Camera]()
    @Published var row1 = [Camera]()
    @Published var row2 = [Camera]()
    @Published var row3 = [Camera]()
    
    @Published var altCamMode: Bool
    @Published var autoSelectMulticam: Camera?
    @Published var autoSelectCamMode = false
    
    var listener: MulticamActionListener?
    
    init(){
        row1 = [Camera]()
        row2 = [Camera]()
        row3 = [Camera]()
        altCamMode = false;
        
    }
    
    func reset(cameras: [Camera]){
        self.cameras = cameras
        row1 = [Camera]()
        row2 = [Camera]()
        row3 = [Camera]()
        altCamMode = false;
        
    }
    func setVerticalAltMainCamera(camera: Camera){
        
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
        
        altCamMode = false
        
        setDefaultLayout()
    }
    func setAltMainCamera(camera: Camera){
        
        row1.removeAll()
        row2.removeAll()
        row3.removeAll()
        
        altCamMode = true
        
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
        
        AppLog.write(">>setAltMainCamera",cameras.count,row1.count,row2.count,row3.count)
        AppLog.write("<<setAltMainCamera")
        
    }
    //need to pass in CGSize to determine if portrait
    func getWidthForCol(camera: Camera,fullWidth: CGSize,camsPerRow: Int,altMode: Bool,mainCam: Camera?) -> CGFloat {
        let isPortrait = fullWidth.height > fullWidth.width
        
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
        
        iconModel.initIcons(isDark: colorScheme == .dark)
        
        if model.cameras.count > 4 {
           
            let mcam = model.cameras[0]

            selectedMulticam = mcam
            model.setAltMainCamera(camera: mcam)
            
            multicamFactory.setCameras(cameras: model.cameras)
        }
        else{
            model.setDefaultLayout()
            multicamFactory.setCameras(cameras: model.cameras)
        }
        
        multicamFactory.delegateListener = self
        
    }
    
    func playAll(){
        multicamFactory.playAll()
        
    }
    func stopAll(){
        multicamFactory.stopAll()
        
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
        let mcv = multicamFactory.getPlayer(camera: camera)
        //mcv.toggleMute()
        
    }
    func rotateCamera(camera: Camera){
        let mcv = multicamFactory.getPlayer(camera: camera)
       // mcv.rotateNext()
        
    }
    func vmdStateChanged(camera: Camera,enabled: Bool){
        multicamFactory.setVmdOn(camera, isOn: enabled)
        
    }
    func disableAltMode(){
        model.turnAltCamModeOff()
        
        
    }
    private func camSelected(cam: Camera,isLandscape: Bool = false){
        AppLog.write("MulticamView:camSelected",cam.getStringUid(),cam.name)
        selectedMulticam = cam
   
        if isLandscape{
            model.setAltMainCamera(camera: cam)
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
    func isAltMode() -> Bool{
        return model.cameras.count <= 4 && model.altCamMode
    }
    var verticalEnabled = UIDevice.current.userInterfaceIdiom != .pad
    var aspectRatio = AppSettings.aspectRatio
    
    @ObservedObject private var keyboard = KeyboardResponder()
    
    
    var body: some View {
        ZStack{
            GeometryReader { fullView in
                let wf = fullView.size
                let wfs = fullView.size.width /// 2 might use for iPhone NXV-PRO
                let bw = 0.6
                if verticalEnabled || wf.height > wf.width {
                    ScrollView(.vertical){
                        VStack(alignment: .leading,spacing: 0){
                            ForEach(model.row1, id: \.self) { cam in
                                multicamFactory.getPlayer(camera: cam).onTapGesture {
                                    camSelected(cam: cam)
                                }
                                .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw * 2)
                                .frame(width: wfs,height: wfs   * aspectRatio)
                            }
                            //HStack{
                                ForEach(model.row2, id: \.self) { cam in
                                    multicamFactory.getPlayer(camera: cam).onTapGesture {
                                        camSelected(cam: cam)
                                    }
                                    .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw * 2)
                                    .frame(width: wfs,height: wfs   * aspectRatio)
                                    //Divider()
                                }
                            // }
                        }
                    }
                }else{
                     
                    ScrollView(.vertical){
                        VStack(alignment: .leading,spacing: 0){
                            if model.altCamMode && fullView.size.width > fullView.size.height - keyboard.currentHeight {
                                HStack(alignment: .top,spacing: 0){
                                    ForEach(model.row1, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw  * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                    }
                                    VStack(spacing: 0){
                                        ForEach(model.row2, id: \.self) { cam in
                                            
                                            let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                            
                                            let vh = vw  * aspectRatio
                                            
                                            multicamFactory.getPlayer(camera: cam).onTapGesture {
                                                camSelected(cam: cam,isLandscape: true)
                                            }
                                            .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                            .frame(width: vw,height: vh)
                                            
                                        }
                                       // Divider()
                                    }
                                    
                                }
                                HStack(spacing: 0){
                                    ForEach(model.row3, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw   * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                        
                                    }
                                    //Divider()
                                }
                            }else{
                                HStack{
                                    ForEach(model.row1, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw  * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                    }
                                   // Divider()
                                }
                                ScrollView(.horizontal){
                                HStack{
                                    ForEach(model.row2, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw  * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
                                        .frame(width: vw,height: vh)
                                        
                                    }
                                    //Divider()
                                }
                                }
                                ScrollView(.horizontal){
                                
                                HStack{
                                    ForEach(model.row3, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw  * aspectRatio
                                        
                                        multicamFactory.getPlayer(camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: bw)
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
}
