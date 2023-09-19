//
//  SingleCameraView.swift
//  nxvpro
//
//  Created by Philip Bishop on 12/02/2022.
//

import SwiftUI


class ZoomState : ObservableObject{
    var currentAmount = 0.0
    var finalAmount = 1.0
    
    
    var currentDragW = 0.0
    var currentDragH = 0.0
    var finalDragW = 0.0
    var finalDragH = 0.0
    
    @Published var contentSize: CGSize = .zero
    @Published var offset = CGSize.zero
    
    var isIosOnMac = false
    
    init(){
        if ProcessInfo.processInfo.isiOSAppOnMac{
            isIosOnMac = true
        }
    }
    
    func resetZoom(){
        currentAmount = 0.0
        finalAmount = 1.0
        currentDragW = 0.0
        currentDragH = 0.0
        finalDragW = 0.0
        finalDragH = 0.0
        
        offset = CGSize.zero
        
        globalCameraEventListener?.toggleSidebarDisabled(disabled: false)
    }
    private func fireShowHideTitlebar(){
        let isZoomed = finalAmount > 1.0
        let isCovering = finalDragH != 1.0  || finalDragW != 0.0
        let hideTitlebar = isZoomed || isCovering
        
        if(!hideTitlebar){
            AppLog.write("ZoomState:fireShowHideTitlebar resetting zoom");
            //resetZoom()
        }
        
            AppLog.write("ZoomState:fireShowHideTitlebar",isZoomed,isCovering,hideTitlebar,finalDragW,finalDragH)
        
        globalCameraEventListener?.toggleSidebarDisabled(disabled: hideTitlebar)
        
    }
    func checkState(){
        fireShowHideTitlebar()
        /*
        let isZoomed = finalAmount > 1.0
        AppLog.write("ZoomState:checkState",isZoomed,finalAmount)
        globalCameraEventListener?.toggleSidebarDisabled(disabled: isZoomed)
         */
    }
    func fixOffset(){
        if isIosOnMac{
            resetZoom()
            return
        }
        finalDragW = finalDragW + currentDragW
        finalDragH = finalDragH + currentDragH;
        
        currentDragW = 0.0
        currentDragH = 0.0
        
        fireShowHideTitlebar()
    }
    func updateOffset(translation: CGSize)->CGSize{
           
        let scaleFactor = finalAmount + currentAmount
        
        //divide by scale factor
        currentDragW = translation.width / scaleFactor
        currentDragH = translation.height / scaleFactor
        
        let tmpOffset = CGSize(width: finalDragW + currentDragW,height: finalDragH + currentDragH)
        //do any bounds checks here
        offset = tmpOffset
        return tmpOffset
        //AppLog.write("DigiZoom",tmpOffset,scaleFactor,model.contentSize)
    }
    func checkNextZoom(amount: Double) -> Bool{
        //AppLog.write("Check amount",finalAmount,amount)
        if finalAmount + amount - 1 >= 1.0 {
            return true
        }
        return false
    }
}

var singleCameraFirstTime = true

class SingleCameraModel : ObservableObject{
    @Published var toolbarHidden = true
    @Published var vmdCtrlsHidden = true
    @Published var ptzCtrlsHidden = true
    @Published var helpHidden = true
    @Published var settingsHidden = true
    @Published var presetsHidden = true
    @Published var imagingHidden = true
    @Published var recordingLabelHidden = true
    @Published var vmdLabelHidden = true
    //used in sheet player
    @Published var playerReady = false
    @Published var isRecording = false
   
    //MARK: Object Detection overlay
    @Published var lastObjectPath: CardData?
    @Published var showLastObject = false
    @Published var showProPlayer = false
    
    var theCamera: Camera?
    func getCameraName() -> String{
        if let cam = theCamera{
            return cam.getDisplayName()
        }
        return ""
    }
    var cameraEventHandler: CameraEventHandler?
    @Published var cameraEventListener: CameraEventListener?
    
    @Published var rotation = Angle(degrees: 0)
   
    func setIsRecording(_ isr: Bool){
        isRecording = isr
        recordingLabelHidden = isRecording == false
    }
    
    @Published var isFullScreen = false
    
    func hideConrols(){
        toolbarHidden = true
        vmdCtrlsHidden = true
        ptzCtrlsHidden = true
        helpHidden = true
        settingsHidden = true
        presetsHidden = true
        imagingHidden = true
        recordingLabelHidden = isRecording == false
        vmdLabelHidden = true
        if let cam = theCamera{
            vmdLabelHidden = cam.vmdOn == false
        }
        
    }
    func hideVmdLabel(){
        vmdLabelHidden = true
    }
}

struct SingleCameraView : View, CameraToolbarListener, VmdEventListener{
    //MARK: VmdEventListener
    func vmdVideoEnabledChanged(camera: Camera, enabled: Bool) {
        thePlayer.playerView.setVmdVideoEnabled(enabled: enabled)
        
    }
    
    func vmdEnabledChanged(camera: Camera, enabled: Bool) {
        //update the toolbar state
        toolbar.setVmdEnabled(camera, enabled: enabled)
        motionDetectionLabel.setVmdMode(camera: camera)
        
        thePlayer.playerView.setVmdEnabled(enabled: enabled)
        //don't do this before camera ready
        if thePlayer.isPlaying(){
            model.vmdLabelHidden = !enabled
        }else{
            model.vmdLabelHidden = true//!enabled
        }
        
        
    }
    
    func vmdSensitivityChanged(camera: Camera, sens: Int) {
        thePlayer.playerView.setVmdSensitivity(sens: sens)
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
    
    @ObservedObject private var keyboard = KeyboardResponder()
    @ObservedObject var model = SingleCameraModel()
    
    let thePlayer = CameraStreamingView()
    let toolbar = CameraToolbarView()
    let vmdCtrls = VMDControls()
    let helpView = ContextHelpView()
    let settingsView = CameraPropertiesView()
    let ptzControls = PTZControls()
    let presetsView = PtzPresetView()
    let imagingCtrls = ImagingControlsContainer()
    
    var motionDetectionLabel = MotionDetectionLabel()
    
    //MARK: Digital Zoom
    @ObservedObject var zoomState = ZoomState()
    var zoomOverly = DigiZoomCompactOverlay()
    
    func setCamera(camera: Camera,listener: VLCPlayerReady,eventListener: CameraEventListener){
        model.theCamera = camera
        model.cameraEventListener = eventListener
        toolbar.setCamera(camera: camera)
        motionDetectionLabel.setVmdMode(camera: camera)
        motionDetectionLabel.setActive(isStart: false)
        model.vmdLabelHidden = true
        model.showLastObject = false
        
        model.cameraEventHandler = CameraEventHandler(model: model,toolbar: toolbar,ptzControls: ptzControls,settingsView: settingsView,helpView: helpView,presetsView: presetsView,imagingCtrls: imagingCtrls)
        
        if let handler = model.cameraEventHandler{
            
            vmdCtrls.setCamera(camera: camera, listener: self)
            thePlayer.playerView.motionListener = vmdCtrls
            ptzControls.setCamera(camera: camera, toolbarListener: self, presetListener: handler)
            thePlayer.setCamera(camera: camera,listener: listener)
            
            
            handler.getPresets(cam: camera)
            handler.getImaging(camera: camera)
        }
        
        zoomState.resetZoom()
    }
    func stop(camera: Camera) -> Bool{
        hideControls()
        
        zoomState.resetZoom()
        model.showLastObject = false
        model.vmdLabelHidden  = true
        model.setIsRecording(false)
        return thePlayer.stop(camera: camera)
    }
    func hideControls(){
        model.hideConrols()
        
    }
    func hideVmdLabel(){
        model.vmdLabelHidden = true
    }
    func showToolbar(){
        model.toolbarHidden = false
        if let cam = model.theCamera{
            AppLog.write("SingleCameraView:showToolbar VMD on",cam.vmdOn)
            model.vmdLabelHidden = cam.vmdOn == false
        }
    }
    func canStartNextRecording(_ camera: Camera) -> Bool{
        if model.isRecording == false{
            if let cam = model.theCamera{
                if cam.sameAs(camera: camera){
                    return true
                }
            }
        }
        return false
    }
    func onRecordingTerminated(){
        toolbar.stopTimer()
        toolbar.setSettingsEnabled(enabled: true)
        toolbar.iconModel.recordingStatusChange(status: false)
        model.setIsRecording(false)
    }
    //MARK: ContextHelpViewListener
    func onCloseHelp() {
        model.helpHidden = true
    }
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        //Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging
        
        guard let cam = model.theCamera else{
            AppLog.write("SingleCameraView:itemSelected model.theCamera == nil")
            return
        }
        if cameraEvent == .bodyDetection{
            cam.vmdOn = !cam.vmdOn
            cam.vmdMode = cam.vmdOn ? 1 : 0
            cam.save()
            vmdEnabledChanged(camera: cam, enabled: cam.vmdOn)
            //need to set vmd controls to disabled
            vmdCtrls.model.vmdEnabled = false
            
            
            RemoteLogging.log(item: "Object detection enabled " + (cam.vmdOn ? "ON" : "OFF") + " " + cam.getDisplayName())
            
            return
        }
        
        if let handler = model.cameraEventHandler{
            handler.itemSelected(cameraEvent: cameraEvent, thePlayer: thePlayer)
        }
    }
    
    func setOrientation(orientation: UIInterfaceOrientation){
        /*
         if orientation == UIInterfaceOrientation.portrait{
         toolbar.setOrientation(isLandscape: false)
         }else{
         toolbar.setOrientation(isLandscape: true)
         }
         */
    }
    
    //MARK: BODY
    var body: some View {
        GeometryReader { geo in
            //let sizeTouse = UIDevice.current.userInterfaceIdiom == .pad ? geo.size : CGSize(width: UIScreen.main.bounds.width,height: UIScreen.main.bounds.height)
            ZStack(alignment: .center){//center iphone origin bottom
                
                VStack(alignment: .leading,spacing: 0){ //leading iphone orig center
                    thePlayer.rotationEffect(model.rotation)
                        .offset(zoomState.offset)
                        .scaleEffect(zoomState.finalAmount + zoomState.currentAmount)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { amount in
                                    //digital zoom
                                    if zoomState.isIosOnMac == false && thePlayer.isPlaying(){
                                        zoomState.contentSize = geo.size //sizeToUse
                                        if zoomState.isIosOnMac==false{
                                            if zoomState.checkNextZoom(amount: amount){
                                                zoomState.currentAmount = amount - 1
                                            }
                                        }
                                    }
                                }
                                .onEnded { amount in
                                    if zoomState.isIosOnMac==false && thePlayer.isPlaying(){
                                        zoomState.finalAmount += zoomState.currentAmount
                                        
                                        zoomState.currentAmount = 0
                                        
                                        zoomState.checkState()
                                    }
                                }
                        )
                        .simultaneousGesture(DragGesture()
                            .onChanged { gesture in
                                if zoomState.isIosOnMac==false && thePlayer.isPlaying(){
                                    zoomState.updateOffset(translation: gesture.translation)
                                }
                            }.onEnded{_ in
                                if zoomState.isIosOnMac==false && thePlayer.isPlaying(){
                                    zoomState.fixOffset()
                                    zoomState.checkState()
                                }
                            }
                        ).clipped()//.clipShape(Rectangle())
                    
                }
                
                VStack{
                    Spacer()
                    ZStack{
                        toolbar.hidden(model.toolbarHidden)
                        ptzControls.hidden(model.ptzCtrlsHidden)
                        vmdCtrls.hidden(model.vmdCtrlsHidden)
                    }
                }
                /*
                 toolbar.hidden(model.toolbarHidden)
                 ptzControls.hidden(model.ptzCtrlsHidden)
                 vmdCtrls.hidden(model.vmdCtrlsHidden)
                 */
                VStack(spacing: 0){
                    motionDetectionLabel.hidden(model.vmdLabelHidden)
                    
                    Text("RECORDING").appFont(.caption)
                        .foregroundColor(Color.white)
                        .padding(5)
                        .background(Color.red)
                        .cornerRadius(10)
                        .hidden(model.recordingLabelHidden)
                    Spacer()
                    HStack(spacing: 0){
                        Spacer()
                        ZStack{
                            helpView.hidden(model.helpHidden)
                            settingsView.hidden(model.settingsHidden).padding(.bottom,keyboard.currentHeight)
                            presetsView.hidden(model.presetsHidden)
                        }
                    }
                    Spacer()
                    
                }.padding(.top,3)
                HStack(spacing: 0){
                    VStack(spacing: 0){
                        Spacer()
                        imagingCtrls.padding()
                        Spacer()
                    }//.padding()
                    Spacer()
                }.hidden(model.imagingHidden)
                
                VStack(spacing: 0){
                    zoomOverly.hidden(zoomState.offset == CGSize.zero && zoomState.finalAmount == 1.0)
                    Spacer()
                }
                if model.showLastObject && geo.size.width > 400{
                    objectOverlayView(viewSize: geo.size)
                }
            }
            .fullScreenCover(isPresented: $model.showProPlayer, content: {
                if let card = model.lastObjectPath{
                    ProVideoPlayer(videoUrl: card.filePath,title: card.getTitle())
                }
            })
            
            .onAppear{
                toolbar.setListener(listener: self)
                settingsView.model.listener = self
                //digital zoom
                //model.contentSize = geo.size
                zoomState.contentSize = geo.size
                
                if singleCameraFirstTime{
                    singleCameraFirstTime = false
                    //globalCameraEventListener?.playerDidAppear()
                }
                AppLog.write("SingleCameraView:body",geo.size,geo.safeAreaInsets)
            }
            
        }
    }
    
    //MARK: Object Detection overlay
    func showOverlay(_ video: URL){
        let nsImage = video.path.replacingOccurrences(of: ".mp4", with: ".png")
        var name = "object event"
        if let cam = model.theCamera{
            name = cam.getDisplayName()
        }
        let cardData = CardData(image: nsImage, name: name, date: Date(),filePath: video)
        cardData.isEvent = true
        
        let eventMeta = video.path.replacingOccurrences(of: ".mp4", with: ".json")
        
        cardData.isObjectEvent = FileManager.default.fileExists(atPath: eventMeta)
        
        if cardData.isObjectEvent{
            let eventMetaPath = URL(fileURLWithPath: eventMeta)
            let med = MotionMetaData()
            med.load(fromFile: eventMetaPath)
            cardData.confidence = med.confidence
            if let objectInfo = med.info{
                if objectInfo.isEmpty == false{
                    cardData.objectTitle = objectInfo
                   
                    //appDelegate?.showAnprNotification(card: cardData)
                }
            }
        }
        
        model.lastObjectPath = cardData
        model.showLastObject = true
        
    }
    
    func objectOverlayView(viewSize: CGSize) -> some View{
        ZStack(alignment: .topLeading){
            VStack{
                HStack{
                    Spacer()
                    if let data = model.lastObjectPath{
                        
                        ZStack(alignment: .topTrailing){
                            Image(uiImage: data.getThumb())
                                .resizable()
                                .cornerRadius(5)
                            
                            let iconCol = data.getEventColor()
                            if data.isEvent{
                                Image(systemName: data.getEventIcon()).resizable()
                                    .foregroundColor(iconCol)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .frame(width: 20, height: 20)
                                    .padding(3)
                                
                            }
                            if data.confidence > 0{
                                VStack{
                                    Spacer()
                                    Text(data.confidenceString()).appFont(.smallFootnote)
                                        .foregroundColor(.white)
                                        .background(iconCol)
                                        .padding()
                                }
                            }
                            
                        }.frame(width: 200, height: 112)
                            .cornerRadius(15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.green, lineWidth: 1.5)
                            )
                            .onTapGesture {
                                model.showLastObject = false
                                if let vp = model.lastObjectPath{
                                    model.showProPlayer = true
                                }
                                
                            }
                        
                    }
                    
                }.padding()
                    Spacer()
            }
        }
    }

    
}
