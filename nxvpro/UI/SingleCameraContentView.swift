//
//  SingleCameraContentView.swift
//  nxvpro
//
//  Created by Philip Bishop on 01/06/2022.
//

import SwiftUI

class SingleCameraContentModel : ObservableObject, NXCameraTabSelectedListener{
    @Published var selectedCameraTab = CameraTab.live // so the video view renders on startup
    //@Published var playerVisible = true
    func tabSelected(tabIndex: CameraTab) {
        self.selectedCameraTab = tabIndex
    }
}

struct SingleCameraContentView: View {
    
    @ObservedObject var model = SingleCameraContentModel()
    
    //MARK: Camera tabs
    var cameraTabHeader =  NXCameraTabHeaderView()
    let player = SingleCameraView()
    let deviceInfoView = DeviceInfoView()
    let storageView = StorageTabbedView()
    let locationView = CameraLocationView()
    let systemView = SystemView()
    let systemLogView = SystemLogView()
    
    func initCameraTabs(camera: Camera,cameras: DiscoveredCameras,listener: GroupChangedListener){
        cameraTabHeader.setCurrrent(camera: camera)
        deviceInfoView.setCamera(camera: camera, cameras: cameras, listener: listener)
        storageView.setCamera(camera: camera)
        locationView.setCamera(camera: camera, allCameras: cameras.cameras, isGlobalMap: false)
        systemView.setCamera(camera: camera)
        systemLogView.setCamera(camera: camera)
        
       // model.playerVisible = true
    }
    func setCamera(camera: Camera,listener: VLCPlayerReady,eventListener: CameraEventListener){
        player.setCamera(camera: camera, listener: listener, eventListener: eventListener)
    }
    func resetZoom(){
        player.zoomState.resetZoom()
    }
    func stop(camera: Camera) -> Bool{
        //model.playerVisible = false
        return player.stop(camera: camera)
    }
    func showToolbar(){
        player.showToolbar()
    }
    func hideControls(){
        player.hideControls()
    }
    func tabSelected(tab: CameraTab){
        print("SingleCameraContentView:tabSelected",tab)
        model.tabSelected(tabIndex: tab)
    }
    func touchOnDevice(){
        storageView.touchOnDevice()
        DispatchQueue.main.async {
            storageView.onDeviceView.refresh()
        }
    }
    
    func refreshCameraProperties(mainCam: Camera,cameras: DiscoveredCameras,listener: GroupChangedListener) {
        deviceInfoView.setCamera(camera: mainCam, cameras: cameras, listener: listener)
    }
    func onCameraNameChanged(camera: Camera){
        cameraTabHeader.setCurrrent(camera: camera)
    }
    
    var poff = CGFloat(-25)
    
    var body: some View {
        VStack{
           
            cameraTabHeader.padding(.bottom,0).hidden(model.selectedCameraTab == .none)
            
            ZStack{
                player.padding(.bottom)//.hidden(model.selectedCameraTab != CameraTab.live)
            
                deviceInfoView.hidden(model.selectedCameraTab != CameraTab.device)
                storageView.hidden(model.selectedCameraTab != CameraTab.storage)
                locationView.hidden(model.selectedCameraTab != CameraTab.location)
                systemView.hidden(model.selectedCameraTab != CameraTab.users)
                systemLogView.hidden(model.selectedCameraTab != CameraTab.system)
                
            }.background(model.selectedCameraTab == CameraTab.live  ? .black : Color(UIColor.secondarySystemBackground))
                .hidden(model.selectedCameraTab == .none)
            
        }.onAppear(){
            cameraTabHeader.setListener(listener: model)
            
        }
    }
}

struct SingleCameraContentView_Previews: PreviewProvider {
    static var previews: some View {
        SingleCameraContentView()
    }
}
