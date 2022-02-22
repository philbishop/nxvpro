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
    
    var listener: CameraEventListener?
}

struct NxvProCamerasView: View, CameraFilterChangeListener {
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var cameras: DiscoveredCameras
    @ObservedObject var model = NxvProCamerasModel()
    
    let bottomAppToolbar = NxvProAppToolbar()
    
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
    //MARK: CameraFilterChangeListener
    func onFilterCameras(filter: String) {
        model.filter = filter
    }
    
    var body: some View {
        VStack{
            List{
                if cameras.cameras.count == 0{
                    Text("No cameras found").appFont(.caption)
                }else{
                    ForEach(cameras.cameras, id: \.self) { cam in
                        if cam.matchesFilter(filter: model.filter){
                            DiscoCameraViewFactory.getInstance(camera: cam).onTapGesture {
                                model.selectedCamera = cam
                                
                                model.listener?.onCameraSelected(camera: cam, isMulticamView: false)
                                
                            }.background(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }
                }
            }.listStyle(PlainListStyle()).padding(0)
            Spacer()
            bottomAppToolbar.padding(.leading)
        }.onAppear {
            iconModel.initIcons(isDark: colorScheme == .dark)
            cameraFilterListener = self
        }
    }
}


