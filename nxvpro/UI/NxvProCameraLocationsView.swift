//
//  NxvProCameraLocationsView.swift
//  nxvpro
//
//  Created by Philip Bishop on 17/02/2022.
//

import SwiftUI

struct NxvProCameraLocationsView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var cameras: DiscoveredCameras
    
    @ObservedObject var model = NxvProCamerasModel()
    
    init(cameras: DiscoveredCameras){
        self.cameras = cameras
    }
    
    func setListener(listener: CameraEventListener){
        model.listener = listener
    }
    var body: some View {
        let camera = self.cameras.cameras
        let hasUnassigned = self.cameras.cameraGroups.hasUnassignedCameras(allCameras: self.cameras.cameras)
        
        List{
            if cameras.cameras.count == 0{
                Text("No cameras found").appFont(.caption)
            }
            if hasUnassigned{
                Section(header: Text("Cameras")) {
                    ForEach(cameras.cameras, id: \.self) { cam in
                        if !cam.isNvr() && !cameras.cameraGroups.isCameraInGroup(camera: cam){
                            CameraLocationViewFactory.getInstance(camera: cam).onTapGesture{
                                model.selectedCamera = cam
                                model.listener?.onCameraLocationSelected(camera: cam)
                            }.listRowBackground(model.selectedCamera == cam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }
                }
            }
            ForEach(cameras.cameraGroups.groups, id: \.self) { grp in
                Section(header: LocationHeader(group: grp)) {
                    
                    ForEach(grp.getCameras(), id: \.self) { vcam in
                        CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                            model.selectedCamera = vcam
                            model.listener?.onCameraLocationSelected(camera: vcam)
                        }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                    }
                }
            }
            ForEach(camera, id: \.self) { cam in
                if cam.isNvr(){
                    Section(header: LocationHeader(nvr: cam)){
                        ForEach(cam.vcams, id: \.self) { vcam in
                            CameraLocationViewFactory.getInstance(camera: vcam).onTapGesture{
                                model.selectedCamera = vcam
                                model.listener?.onCameraLocationSelected(camera: vcam)
                            }.listRowBackground(model.selectedCamera == vcam ? Color(iconModel.selectedRowColor) : Color(UIColor.clear)).padding(0)
                        }
                    }
                }
            }
        }.listStyle(PlainListStyle())
    }
}


