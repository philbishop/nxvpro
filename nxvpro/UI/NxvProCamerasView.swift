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
    
    let bottomAppToolbar = NxvProAppToolbar()
    
    //remove camera
    @State var showDelete = false
    @State var camToDelete: Camera?
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
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
    func toggleMoveMode(){
        model.moveMode = !model.moveMode
        if model.moveMode == false{
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
                cameras.sortByDisplayOrder()
            })
        }
        DiscoCameraViewFactory.makeThumbVisible(viz: model.moveMode==false)
    }
    func onListMove(from source: IndexSet, to destination: Int)
    {
        print("onListMove",source,destination)
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
    //MARK: CameraFilterChangeListener
    func onFilterCameras(filter: String) {
        model.filter = filter
        
    }
    
    var body: some View {
        let groups = cameras.cameraGroups
        VStack{
            List{
                if cameras.cameras.count == 0{
                    Text("No cameras found").appFont(.caption)
                }else{
                    ForEach(cameras.cameras, id: \.self) { cam in
                        //hide all cameras in groups
                        if cam.matchesFilter(filter: model.filter) && !groups.isCameraInGroup(camera: cam){
                            DiscoCameraViewFactory.getInstance(camera: cam).onTapGesture {
                                model.selectedCamera = cam
                                
                                model.listener?.onCameraSelected(camera: cam, isMulticamView: false)
                                
                            }.onLongPressGesture(minimumDuration: 2) {
                                
                                showDelete = true
                                camToDelete = cam
                                print("longPressGuesture",cam.getDisplayName(),cam.getBaseFileName())
                            }.alert(isPresented: $showDelete) {
                                
                                Alert(title: Text("Remove: " + camToDelete!.getDisplayName()), message: Text("Remove the camera until it is discovered again?\n\n WARNING: If the camera was added manually you will have to add it again."),
                                      primaryButton: .default (Text("Remove")) {
                                    showDelete = false
                                        print("Remove camera tapped")
                                        globalCameraEventListener?.deleteCamera(camera: camToDelete!)
                                      },
                                      secondaryButton: .cancel() {
                                        showDelete = false
                                      }
                                )
                            }
                            .background(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }.onMove(perform: onListMove)
                }
            }.listStyle(PlainListStyle())
            Spacer()
            bottomAppToolbar.padding(.leading)
            
        }.onAppear {
            iconModel.initIcons(isDark: colorScheme == .dark)
            cameraFilterListener = self
            bottomAppToolbar.setLocalListener(listener: self)
        }.environment(\.editMode, model.moveMode ? .constant(.active) : .constant(.inactive))
    }
}


