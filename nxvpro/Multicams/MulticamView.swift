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
        
            print("Move row 2 camera to row 1 pos 1")
        
            let firstCam = row1[0]
            
            var tmp = [Camera]()
            for cam in cameras {
                if cam.id != camera.id  && cam.id != firstCam.id{
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
            if cam.id != camera.id {
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
        
        print(">>setAltMainCamera",cameras.count,row1.count,row2.count,row3.count)
        print("<<setAltMainCamera")
        
    }
    //need to pass in CGSize to determine if portrait
    func getWidthForCol(camera: Camera,fullWidth: CGSize,camsPerRow: Int,altMode: Bool,mainCam: Camera?) -> CGFloat {
        let isPortrait = fullWidth.height > fullWidth.width
        
        if altMode && mainCam != nil && mainCam!.id == camera.id {
            if isPortrait{
                return fullWidth.width
            }
            return fullWidth.width * CGFloat(0.75)
        }
        
        if altMode{
            if isPortrait{
                for cam in row2 {
                    if cam.id == camera.id{
                        
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

struct MulticamRowItem : View{
    
    @ObservedObject var multicamFactory: MulticamFactory
    
    var cam: Camera
    
    init(factory: MulticamFactory,camera: Camera){
        self.multicamFactory = factory
        self.cam = camera
        
        //print("MulticamRowItem",camera.xAddr,camera.getDisplayName())
    }
    
    var body: some View {
        ZStack(alignment: .top){
            ZStack{
                multicamFactory.getPlayer(camera: cam)
                Text(multicamFactory.playersReadyStatus[cam.id]!).appFont(.smallCaption)
                    .foregroundColor(Color.white).hidden(multicamFactory.playersReady[cam.id]!)
            }
            
            HStack(alignment: .top){
                Text(" MOTION ON ").foregroundColor(Color.white).background(Color.green)
                   .appFont(.smallCaption)
                    .padding(10)
                    .hidden(multicamFactory.vmdOn[cam.id] == false)
                
                Spacer()
                
                Text(" RECORDING ").foregroundColor(Color.white).background(Color.red)
                   .appFont(.smallCaption)
                    .padding(10).hidden(multicamFactory.isRecording[cam.id] == false)
                
            }.frame(alignment: .top)
        }
    }
}

struct MulticamView2: View , VLCPlayerReady{
    
    //MARK: VLCPLayerReady
    func onRecordingEnded(camera: Camera) {
        //TO DO
    }
    func onPlayerReady(camera: Camera) {
        AppLog.write("MulticamView2:onPlayerReady",camera.id,camera.name)
        DispatchQueue.main.async {
            multicamFactory.playersReady[camera.id] = true
        }
    }
    func onRecordingTerminated(camera: Camera) {
        AppLog.write("MulticamView2:onRecordingTerminated",camera.id,camera.name)
    }
    func onBufferring(camera: Camera,pcent: String) {
        DispatchQueue.main.async {
            multicamFactory.playersReadyStatus[camera.id] = pcent//"Bufferring " + camera.getDisplayName()
            
        }
    }
    func connectAuthFailed(camera: Camera){
        onError(camera: camera, error: "Authentication failed")
    }
    func onSnapshotChanged(camera: Camera) {
        AppLog.write("MulticamView2:onSnapshotChanged",camera.id,camera.name)
    }
    
    func onError(camera: Camera, error: String) {
        DispatchQueue.main.async {
            multicamFactory.playersReadyStatus[camera.id] = error//"Bufferring " + camera.getDisplayName()
            
        }
        AppLog.write("MulticamView2:onError",camera.id,camera.name,error)
    }
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model = MulticamViewModel()
    @ObservedObject var multicamFactory = MulticamFactory()
    
    @State var selectedMulticam: Camera?
    @State var selectedPlayer: CameraStreamingView?
    
    func isPlayerReady(cam: Camera) -> Bool {
        return multicamFactory.playersReady[cam.id]!
    }
    
    func setCameras(cameras: [Camera],listener: MulticamActionListener){
        
        print("MulticamView:setCameras",cameras.count)
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
        
        
    }
    
    func playAll(){
        multicamFactory.playAll()
        
    }
    func stopAll(){
        multicamFactory.stopAll()
        
    }
    func onIsAlive(camera: Camera) {
        //nothing to do yet
    }
    func toggleRecordingState(camera: Camera){
        if let recording = multicamFactory.isRecording[camera.id]{
            multicamFactory.isRecording[camera.id] = !recording
        }
        
    }
    //Old code called directly
    func startStopRecording(camera: Camera) -> Bool {
        let mcv = multicamFactory.getPlayer(camera: camera)
        let recording = mcv.startStopRecording(camera: camera)
        multicamFactory.isRecording[camera.id] =  recording
        return recording
    }
    func toggleMute(camera: Camera){
        let mcv = multicamFactory.getPlayer(camera: camera)
        mcv.toggleMute()
        
    }
    func rotateCamera(camera: Camera){
        let mcv = multicamFactory.getPlayer(camera: camera)
        mcv.rotateNext()
        
    }
    func vmdStateChanged(camera: Camera,enabled: Bool){
        multicamFactory.vmdOn[camera.id] = enabled
        
    }
    func disableAltMode(){
        model.turnAltCamModeOff()
        
        
    }
    private func camSelected(cam: Camera,isLandscape: Bool = false){
        print("MulticamView:camSelected",cam.id,cam.name)
        selectedMulticam = cam
   
        if isLandscape{
            model.setAltMainCamera(camera: cam)
        }else if Camera.IS_NXV_PRO{
            model.setVerticalAltMainCamera(camera: cam)
        }
        
        let player = multicamFactory.getPlayer(camera: cam)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25,execute:{
            model.listener?.multicamSelected(camera: cam,mcPlayer: player)
        });
    }
    
    func recordingTerminated(camera: Camera){
        print("MulticamView:recordingTerminated",camera.id,camera.name)
        multicamFactory.isRecording[camera.id] = false
    }
    func isAltMode() -> Bool{
        return model.cameras.count <= 4 && model.altCamMode
    }
    var verticalEnabled = UIDevice.current.userInterfaceIdiom != .pad
    
    
    var body: some View {
        ZStack{
            GeometryReader { fullView in
                let wf = fullView.size
                let wfs = fullView.size.width /// 2 might use for iPhone NXV-PRO
                
                if verticalEnabled && wf.height > wf.width {
                    ScrollView(.vertical){
                        VStack(alignment: .leading,spacing: 4){
                            ForEach(model.row1, id: \.self) { cam in
                                MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                    camSelected(cam: cam)
                                }
                                .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                .frame(width: wf.width,height: wf.width / 1.67)
                                Divider()
                            }
                            //HStack{
                                ForEach(model.row2, id: \.self) { cam in
                                    MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                        camSelected(cam: cam)
                                    }
                                    .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                    .frame(width: wfs,height: wfs / 1.67)
                                    Divider()
                                }
                            // }
                        }
                    }
                }else{
                     
                    ScrollView(.vertical){
                        VStack(alignment: .leading){
                            if model.altCamMode && fullView.size.width > fullView.size.height {
                                HStack(alignment: .top){
                                    ForEach(model.row1, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw / 1.67
                                        
                                        MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                        .frame(width: vw,height: vh)
                                    }
                                    VStack(spacing: 1){
                                        ForEach(model.row2, id: \.self) { cam in
                                            
                                            let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                            
                                            let vh = vw / 1.67
                                            
                                            MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                                camSelected(cam: cam,isLandscape: true)
                                            }
                                            .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                            .frame(width: vw,height: vh)
                                            
                                        }
                                        Divider()
                                    }
                                    
                                }
                                HStack{
                                    ForEach(model.row3, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw / 1.67
                                        
                                        MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                        .frame(width: vw,height: vh)
                                        
                                    }
                                    Divider()
                                }
                            }else{
                                HStack{
                                    ForEach(model.row1, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw / 1.6
                                        
                                        MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                        .frame(width: vw,height: vh)
                                    }
                                    Divider()
                                }
                                ScrollView(.horizontal){
                                HStack{
                                    ForEach(model.row2, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw / 1.66
                                        
                                        MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                        .frame(width: vw,height: vh)
                                        
                                    }
                                    Divider()
                                }
                                }
                                ScrollView(.horizontal){
                                
                                HStack{
                                    ForEach(model.row3, id: \.self) { cam in
                                        
                                        let vw = model.getWidthForCol(camera: cam, fullWidth: fullView.size, camsPerRow: 2, altMode: model.altCamMode, mainCam: selectedMulticam)
                                        
                                        let vh = vw / 1.66
                                        
                                        MulticamRowItem(factory: multicamFactory, camera: cam).onTapGesture {
                                            camSelected(cam: cam,isLandscape: true)
                                        }
                                        .border(cam == selectedMulticam ? Color.accentColor : Color.clear,width: 3)
                                        .frame(width: vw,height: vh)
                                        
                                    }
                                    Divider()
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
            print("MulticamView:onAppear",model.cameras.count)
            
            initModels()
        }
    }
}
