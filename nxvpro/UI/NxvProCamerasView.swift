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
        bottomAppToolbar.setMulticamActive(active: active)
    }
    
    //MARK: Drag Move
    func disableMove(){
        model.moveMode = false
    }
    func toggleMoveMode(){
        model.moveMode = !model.moveMode
        if model.moveMode == false{
            cameras.sortByDisplayOrder()
        }
        DiscoCameraViewFactory.makeThumbVisible(viz: model.moveMode==false)
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
            }
        }
        return cams
    }
    //MARK: CameraFilterChangeListener
    func onFilterCameras(filter: String) {
        model.filter = filter
        
    }
    
    var body: some View {
        let groups = cameras.cameraGroups
        let ncams = cameras.cameras.count
        let camsToUse = getMatchingCameras()
        
        let allInGrps = cameras.hasAllCamsInGroups(others: netStream.cameras)
        let tbEnabled = allInGrps == false && ncams > 0
        
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
                            DiscoCameraViewFactory.getInstance(camera: cam).onTapGesture {
                                /*
                                if let selCam = model.selectedCamera{
                                    if selCam.isAuthenticated() && selCam.getStringUid() == cam.getStringUid(){
                                        return
                                    }
                                }
                                 */
                                model.selectedCamera = cam
                                
                                model.listener?.onCameraSelected(camera: cam, isCameraTap: true)
                                DiscoCameraViewFactory.setCameraSelected(camera: cam)
                                
                            }//.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .contextMenu {
                                    Button {
                                        AppLog.write("Reset login invoked")
                                        showReset = true
                                        camToDelete = cam
                                        showAlert = true
                                    } label: {
                                        Label("Reset login", systemImage: "person.fill.xmark")
                                    }

                                    Button {
                                        AppLog.write("Delete camera invoked")
                                        showDelete = true
                                        camToDelete = cam
                                        showAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            .alert(isPresented: $showAlert) {
                                
                                Alert(title: Text( showDelete ? "Delete: " : "Reset: " + camToDelete!.getDisplayName()),
                                      message: Text(showReset ? "Reset login details" : "Remove the camera until it is discovered again?\n\n WARNING: If the camera was added manually you will have to add it again."),
                                              primaryButton: .default (Text(showDelete ? "Delete" : "Reset")) {
                                            
                                            AppLog.write(showDelete ? "Delete: " : "Reset: " + " camera login tapped")
                                            if showReset{
                                                    globalCameraEventListener?.resetCamera(camera: camToDelete!)
                                            }else{
                                                globalCameraEventListener?.deleteCamera(camera: camToDelete!)
                                            }
                                            showAlert = false
                                            showReset = false
                                            showDelete = false
                                        },
                                            secondaryButton: .cancel() {
                                            showReset = false
                                            showDelete = false
                                            showAlert = false
                                        }
                                    )


                            }.listRowBackground(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear))
                            
                            //.background(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }.onMove(perform: onListMove)
                }
            }.listStyle(PlainListStyle())
                .onAppear {
                    UITableView.appearance().showsVerticalScrollIndicator = false
                    bottomAppToolbar.setPlayAndOrderEnabled(tbEnabled)
                    
                }
            
            bottomAppToolbar.padding(.top,10)
                
                                
            
        }
        .padding(0)
        .onAppear {
            iconModel.initIcons(isDark: colorScheme == .dark)
            cameraFilterListener = self
            bottomAppToolbar.setLocalListener(listener: self)
        }.environment(\.editMode, model.moveMode ? .constant(.active) : .constant(.inactive))
    }
}


