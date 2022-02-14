//
//  LocationGroupHeader.swift
//  NX-V
//
//  Created by Philip Bishop on 23/01/2022.
//

import SwiftUI

class LocationHeaderModel : ObservableObject {

    @Published var groupName: String
    
    var group: CameraGroup
    var cameras = [Camera]()
    
    init(nvr: Camera){
        group = CameraGroup()
        group.name = nvr.getDisplayName()
        nvr.getVirtualCameras()
        group.cameras = nvr.vcams
        groupName = group.name
        
    }
    
    init(group: CameraGroup){
        self.group = group
        self.groupName = group.name
        self.cameras = group.cameras
    }
}

struct LocationHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    
    @ObservedObject var model: LocationHeaderModel
   
    init(nvr: Camera){
        self.model = LocationHeaderModel(nvr: nvr)
    }
    
    init(group: CameraGroup){
        self.model = LocationHeaderModel(group: group)
    }
    var body: some View {
        HStack{
            Text(model.groupName).appFont(.smallCaption).frame(alignment: .leading)
            Spacer()
            Button(action:{
                print("Open mini map for group NOT Implemented yet")
                //globalToolbarListener?.openMiniMap(group: model.group)
            }){
                Image(systemName: "mappin").resizable().rotationEffect(Angle(degrees: 180))
                    .frame(width: 14, height: 14, alignment: .center)
                    .padding(.trailing)
            }.buttonStyle(PlainButtonStyle())
                
        }
    }
}
