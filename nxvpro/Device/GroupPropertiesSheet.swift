//
//  GroupPropertiesSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 18/02/2022.
//

import SwiftUI

protocol NXSheetDimissListener{
    func dismissSheet()
}

class GroupPropertiesSheetModel : ObservableObject{
    @Published var groupName = ""
    @Published var group: CameraGroup?
    
    var camera: Camera?
    var dimissListener: NXSheetDimissListener?
    var changeListener: GroupChangedListener?
}

struct GroupPropertiesSheet: View {
    @ObservedObject var model = GroupPropertiesSheetModel()
    
    init(camera: Camera,group: CameraGroup,listener: NXSheetDimissListener,changeListener: GroupChangedListener){
        model.camera = camera
        model.group = group
        model.groupName = group.name
        model.dimissListener = listener
        model.changeListener = changeListener
    }
    init(group: CameraGroup,listener: NXSheetDimissListener){
        model.group = group
        model.groupName = group.name
        model.dimissListener = listener
    }
    var body: some View {
        List(){
            VStack (alignment: .leading){
                HStack{
                    VStack{
                        Text("Group properties").appFont(.title)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        //presentationMode.wrappedValue.dismiss()
                        model.dimissListener?.dismissSheet()
                    })
                    {
                        Image(systemName: "xmark").resizable()
                            .frame(width: 18,height: 18).padding()
                    }.foregroundColor(Color.accentColor)
                }
                Section(header: Text("Group name").appFont(.sectionHeader)){
                    HStack(spacing: 10){
                        TextField("Name",text: $model.groupName)
                        Spacer()
                        Button("Apply",action:{
                            print("GroupProperties sheet -> Apply",model.groupName)
                            
                            if let theCamera = model.camera{
                                //this is a new group
                                model.changeListener?.moveCameraToGroup(camera: theCamera, grpName: model.groupName)
                            }else{
                                model.group!.name = model.groupName
                                model.group!.save()
                                //reset the headers
                                GroupHeaderFactory.nameChanged(group: model.group!)
                                globalCameraEventListener?.refreshCameraProperties()
                                model.dimissListener?.dismissSheet()
                            }
                        }).foregroundColor(Color.accentColor)
                    }
                }
            }
            Section(header: Text("Cameras in group").appFont(.sectionHeader)){
                VStack(spacing: 0){
                    ForEach(model.group!.cameras, id: \.self) { cam in
                        HStack{
                            Text(cam.getDisplayName()).appFont(.caption)
                            Text(cam.getDisplayAddr()).appFont(.caption)
                            
                        }
                    }
                }
            }
        }
    }
}


