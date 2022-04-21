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
    func checkState(){
        let isZoomed = finalAmount > 1.4
        print("ZoomState:checkState",isZoomed,finalAmount)
        globalCameraEventListener?.toggleSidebarDisabled(disabled: isZoomed)
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
        //print("DigiZoom",tmpOffset,scaleFactor,model.contentSize)
    }
    func checkNextZoom(amount: Double) -> Bool{
        //print("Check amount",finalAmount,amount)
        if finalAmount + amount - 1 >= 1.0 {
            return true
        }
        return false
    }
}

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
    
    var theCamera: Camera?
    var cameraEventHandler: CameraEventHandler?
    @Published var cameraEventListener: CameraEventListener?
    
    @Published var rotation = Angle(degrees: 0)
   
    //MARK: Digital Zoom
    /*
    //@Published var digiZoomHidden = true
    //@Published var zoom = CGFloat(1)
    @Published var contentSize: CGSize = .zero
    @Published var offset = CGSize.zero
    
    func resetZoom(){
        offset = CGSize.zero
    }
    */
    func hideConrols(){
        toolbarHidden = true
        vmdCtrlsHidden = true
        ptzCtrlsHidden = true
        helpHidden = true
        settingsHidden = true
        presetsHidden = true
        imagingHidden = true
        recordingLabelHidden = true
        vmdLabelHidden = true
        if let cam = theCamera{
            vmdLabelHidden = cam.vmdOn == false
        }
        
    }
}

struct SingleCameraView : View, CameraToolbarListener, VmdEventListener{
    //MARK: VmdEventListener
    func vmdVideoEnabledChanged(camera: Camera, enabled: Bool) {
        thePlayer.playerView.setVmdVideoEnabled(enabled: enabled)
        
    }
    
    func vmdEnabledChanged(camera: Camera, enabled: Bool) {
        thePlayer.playerView.setVmdEnabled(enabled: enabled)
        model.vmdLabelHidden = !enabled
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
    
    //MARK: Digital Zoom
    @ObservedObject var zoomState = ZoomState()
    
     
    func setCamera(camera: Camera,listener: VLCPlayerReady,eventListener: CameraEventListener){
        model.theCamera = camera
        model.cameraEventListener = eventListener
        toolbar.setCamera(camera: camera)
        
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
        
        return thePlayer.stop(camera: camera)
    }
    func hideControls(){
        model.hideConrols()
        
    }
    func showToolbar(){
        model.toolbarHidden = false
    }
    
    //MARK: ContextHelpViewListener
    func onCloseHelp() {
        model.helpHidden = true
    }
    
    //MARK: CameraToolbarListener
    func itemSelected(cameraEvent: CameraActionEvent) {
        //Ptz, Vmd, Mute, Record, Cloud, Rotate, Settings, Help, CloseToolbar, ProfileChanged, CapturedVideos, StopVideoPlayer, StopMulticams, Feedback, StopMulticamsShortcut, Imaging
        
        guard let cam = model.theCamera else{
            print("SingleCameraView:itemSelected model.theCamera == nil")
            return
        }
        
        if let handler = model.cameraEventHandler{
            handler.itemSelected(cameraEvent: cameraEvent, thePlayer: thePlayer)
        }
    }
  
    //MARK: BODY
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom){
                VStack{
                    thePlayer.rotationEffect(model.rotation)
                        .offset(zoomState.offset)
                        .scaleEffect(zoomState.finalAmount + zoomState.currentAmount)
                       .gesture(
                           MagnificationGesture()
                               .onChanged { amount in
                                   //digital zoom
                                   
                                   zoomState.contentSize = geo.size
                                   if zoomState.isIosOnMac==false{
                                       if zoomState.checkNextZoom(amount: amount){
                                           zoomState.currentAmount = amount - 1
                                       }
                                   }
                               }
                               .onEnded { amount in
                                   if zoomState.isIosOnMac==false{
                                       zoomState.finalAmount += zoomState.currentAmount
                                       
                                       zoomState.currentAmount = 0
                                       
                                       zoomState.checkState()
                                   }
                               }
                       )
                       .simultaneousGesture(DragGesture()
                        .onChanged { gesture in
                            if zoomState.isIosOnMac==false{
                                zoomState.updateOffset(translation: gesture.translation)
                            }
                        }.onEnded{_ in
                            zoomState.fixOffset()
                            zoomState.checkState()
                        }
                       ).clipped()//.clipShape(Rectangle())
                    
                }
                toolbar.hidden(model.toolbarHidden)
                ptzControls.hidden(model.ptzCtrlsHidden)
                vmdCtrls.hidden(model.vmdCtrlsHidden)
                
                VStack{
                    Text(" MOTION ON ").appFont(.caption)
                        .foregroundColor(Color.white).background(Color.green).padding(0)
                        .hidden(model.vmdLabelHidden)
                    
                    Text(" RECORDING ").appFont(.caption)
                        .foregroundColor(Color.white).background(Color.red)
                        .padding(0).hidden(model.recordingLabelHidden)
                    Spacer()
                    HStack{
                        Spacer()
                        ZStack{
                            helpView.hidden(model.helpHidden)
                            settingsView.hidden(model.settingsHidden).padding(.bottom,keyboard.currentHeight)
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
                
            }.onAppear{
                toolbar.setListener(listener: self)
                settingsView.model.listener = self
                //digital zoom
                //model.contentSize = geo.size
                zoomState.contentSize = geo.size
                //print("DigiZoom:onAppear",model.contentSize)
            }
        }
    }
}
