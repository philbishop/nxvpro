//
//  NxvProCamerasView.swift
//  nxvpro
//
//  Created by Philip Bishop on 10/02/2022.
//

import SwiftUI


class NxvProCamerasModel : ObservableObject{
    @Published var selectedCamera: Camera?
    @Published var filter: String = ""
    @Published var vizState = 1
    @Published var moveMode = false
    @Published var isMulticamActive = false
    var listener: CameraEventListener?
}

struct NxvProCamerasView: View, CameraFilterChangeListener,NxvProAppToolbarListener {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var cameras: DiscoveredCameras
    @ObservedObject var model = NxvProCamerasModel()
    @ObservedObject var netStream = AllNetStreams()
    
    let bottomAppToolbar = NxvProAppToolbar()
    
    //remove/reset camera
    @State var showDelete = false
    @State var showReset = false
    @State var showAlert = false
    @State var camToDelete: Camera?
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
    }
    func touch(){
        
        model.vizState = model.vizState + 1
    }
    func toggleTouch(){
        model.vizState = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25,execute:{
            model.vizState = 1
            DiscoCameraViewFactory.makeThumbVisible(viz: true)
        })
        
        
    }
    func addNetStream(_ ns: String) -> Camera{
        return netStream.addCamera(netStream: ns)
    }
    
    
    func setListener(listener: CameraEventListener){
        model.listener = listener
        
    }
    func enableRefresh(enable: Bool){
        bottomAppToolbar.enableRefresh(enable: enable)
    }
    func enableMulticams(enable: Bool){
        bottomAppToolbar.enableMulticams(enable: enable)
    }
    func setMulticamActive(active: Bool){
        model.isMulticamActive = active
        bottomAppToolbar.setMulticamActive(active: active)
    }
    
    //MARK: Drag Move
    func disableMove(){
        model.moveMode = false
        
        if #unavailable(iOS 17){
            DiscoCameraViewFactory.makeThumbVisible(viz: model.moveMode==false)
        }
    }
    func toggleMoveMode(){
        debugPrint("MVC:toggleMoveMode",model.moveMode)
        model.moveMode = !model.moveMode
        if model.moveMode == false{
            cameras.sortByDisplayOrder()
        }
        DispatchQueue.main.async{
            DiscoCameraViewFactory.setMoveMode(on: model.moveMode)
            if #unavailable(iOS 17){
                DiscoCameraViewFactory.makeThumbVisible(viz: model.moveMode==false)
            }
        }
    }
    func onListMove(from source: IndexSet, to destination: Int)
    {
        
        AppLog.write(">>>onListMove",source.debugDescription,destination)
        let neworder = DiscoCameraViewFactory.moveView(fromOffsets: source, toOffsets: destination)
        
        for nc in neworder{
            for cam in cameras.cameras{
                if nc.getStringUid() == cam.getStringUid(){
                    cam.displayOrder = nc.displayOrder
                    break
                }
            }
        }
        cameras.saveAll()
        netStream.saveAll()
        //cameras.sortByDisplayOrder()
    }
    func getMatchingCameras()->[Camera]{
        var cams = [Camera]()
        let groups = cameras.cameraGroups
        for cam in cameras.cameras{
            if cam.matchesFilter(filter: model.filter) && !groups.isCameraInGroup(camera: cam){
                cams.append(cam)
            }
        }
        for cam in netStream.cameras{
            if cam.matchesFilter(filter: model.filter) && !groups.isCameraInGroup(camera: cam){
                cams.append(cam)
            }else{
                let matched = cam.matchesFilter(filter: model.filter)
                let inGrp = groups.isCameraInGroup(camera: cam)
                debugPrint("NetStreams getMatchingCameras",matched,inGrp)
            }
        }
        cams.sort{
            $0.displayOrder < $1.displayOrder
        }
        
        bottomAppToolbar.setMoveEnabled(cams.count > 1)
        
        return cams
    }
    //MARK: CameraFilterChangeListener
    func onFilterCameras(filter: String) {
        model.filter = filter
        
    }
    //MARK: Multicam all in groups play
    func getMultiGroupPlayLabel()-> String{
        if model.isMulticamActive{
            return "multiple group streaming active"
        }else{
            return "multiple group streaming available"
        }
    }
    private func canPlayMulticams() -> Bool{
        let authCams = CameraUtils.getAuthenticatedFavsCount(cameras: cameras.cameras, netStreams: netStream.cameras)
        return authCams.count > 1
    }
    var body: some View {
        let groups = cameras.cameraGroups
        //let ncams = cameras.cameras.count
        let camsToUse = getMatchingCameras()
        let ncams = cameras.cameras.count + netStream.cameras.count
        let allInGrps = cameras.hasAllCamsInGroups(others: netStream.cameras)
        let tbEnabled = canPlayMulticams()
        
        VStack(spacing: 0){
            List{
                if ncams == 0{
                    Text("No cameras found").appFont(.caption).foregroundColor(.accentColor)
                        .padding()
                }else if allInGrps{
                    Text("All cameras assigned to groups").appFont(.caption).foregroundColor(.accentColor)
                        .padding()
                }else if model.vizState>0{
                    ForEach(camsToUse, id: \.self) { cam in
                        //hide all cameras in groups
                        if cam.matchesFilter(filter: model.filter) && !groups.isCameraInGroup(camera: cam){
                            
                            DiscoveredCameraViewWrapper(camera: cam, model: model, viewId: 1)
                                .listRowBackground(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear))
                            
                        }
                        
                    }.onMove(perform: onListMove)
                }
            }.listStyle(PlainListStyle())
                .onAppear {
                    UITableView.appearance().showsVerticalScrollIndicator = false
                }
            
            
            if allInGrps && canPlayMulticams(){
                HStack{
                    Spacer()
                    if model.isMulticamActive == false{
                        Image(iconModel.activeFavIcon).resizable().frame(width: 18,height: 18)
                    }
                    Text(getMultiGroupPlayLabel()).appFont(.smallCaption)
                        .foregroundColor(model.isMulticamActive ? .accentColor : Color(UIColor.label))
                    
                    Spacer()
                }
            }
            
            bottomAppToolbar.padding(.top,10)
                
                                
            
        }
        .padding(0)
        .onAppear {
            iconModel.initIcons(isDark: colorScheme == .dark)
            cameraFilterListener = self
            bottomAppToolbar.setLocalListener(listener: self)
            debugPrint("Number of network cameras",netStream.cameras.count)
        }.environment(\.editMode, model.moveMode ? .constant(.active) : .constant(.inactive))
    }
}


