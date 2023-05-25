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
    @Published var allGroups: CameraGroups?
    @Published var canChange = false
    @Published var applyEnabled = false
    @Published var hideCamerasOn = false
    
    var camera: Camera?
    
    var dimissListener: NXSheetDimissListener?
    var changeListener: GroupChangedListener?
    
    func createNewGroup(){
        if let groups = allGroups{
            var maxId = 0
            for cg in groups.groups{
                //if we have an empty group return it
                if cg.cameraIps.count == 0 {
                    group = cg
                    groupName = cg.name
                }
                maxId = max(maxId,cg.id)
            }
            
            let grp = CameraGroup()
            grp.id = maxId + 1
            grp.name = "Group " + String(grp.id)
            //grp.cameraIps.append(camera.getBaseFileName())
            grp.cameras.append(camera!)
            
            group = grp
            groupName = grp.name
        }
    }
}

struct GroupPropertiesSheet: View {
    @ObservedObject var model = GroupPropertiesSheetModel()
    
    //GroupPropertiesSheet(group: model.group,allGroups: model.allGroups, listener: self)
    init(group: CameraGroup,allGroups: [CameraGroup],listener: NXSheetDimissListener){
        model.group = group
        model.groupName = group.name
        model.dimissListener = listener
        model.canChange = true
        
        if let camsVisable = group.camsVisible{
            model.hideCamerasOn = !camsVisable
        }
    }
    init(camera: Camera,groupName: String,allGroups: CameraGroups,listener: NXSheetDimissListener,changeListener: GroupChangedListener){
        model.camera = camera
        model.groupName = groupName
        model.group = allGroups.getGroupFor(camera: camera)
        model.allGroups = allGroups
        model.dimissListener = listener
        model.changeListener = changeListener
        model.canChange = false
    }
    
    var body: some View {
        List(){
            
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
                }.foregroundColor(.accentColor)
            }
            
            if model.canChange{
                Section(header: Text("Group name").appFont(.sectionHeader)){
                    
                    HStack{
                        TextField("Name",text: $model.groupName).appFont(.body)
                        Spacer()
                        Button("Apply",action:{
                            AppLog.write("GroupProperties sheet -> Apply",model.groupName)
                            
                            if let theCamera = model.camera{
                                //this is a new group
                                model.changeListener?.moveCameraToGroup(camera: theCamera, grpName: model.groupName)
                            }else{
                                model.group!.name = model.groupName
                                model.group?.camsVisible = !model.hideCamerasOn
                                model.group!.save()
                                //reset the headers
                                GroupHeaderFactory.nameChanged(group: model.group!)
                                globalCameraEventListener?.refreshCameraProperties()
                                model.dimissListener?.dismissSheet()
                            }
                        }).foregroundColor(Color.accentColor)
                            .appFont(.body)
                            .buttonStyle(.plain)
                            
                    }
                    
                }
            }else{
                Section(header: Text("Groups").appFont(.sectionHeader)){
                    //show existing groups
                    //on change set model.group so cameras in  group updates
                    
                    VStack(alignment: .leading, spacing: 20){
                        if let allGroups = model.allGroups{
                            ForEach(allGroups.groups, id: \.self) { grp in
                                HStack{
                                    Text(grp.name).appFont(.caption)
                                        .foregroundColor(model.groupName == grp.name ? .accentColor : Color(UIColor.label))
                                        .onTapGesture {
                                            model.groupName = grp.name
                                            model.group = grp
                                            model.applyEnabled = true
                                        }
                                }
                            }
                        }
                        HStack{
                            Text(CameraGroup.DEFAULT_GROUP_NAME).appFont(.caption)
                                .foregroundColor(model.groupName == CameraGroup.DEFAULT_GROUP_NAME ? .accentColor : Color(UIColor.label))
                                .onTapGesture {
                                    model.groupName = CameraGroup.DEFAULT_GROUP_NAME
                                    model.group = nil
                                    model.applyEnabled = true
                                }
                        }
                        HStack{
                            Text(CameraGroup.NEW_GROUP_NAME).appFont(.caption)
                                .foregroundColor(model.groupName == CameraGroup.NEW_GROUP_NAME ? .accentColor : Color(UIColor.label))
                                .onTapGesture {
                                    model.groupName = CameraGroup.NEW_GROUP_NAME
                                    model.group = nil
                                    model.applyEnabled = true
                                }
                        }
                    }
                    
                    
                }
                Section(header: Text("Status").appFont(.sectionHeader)){
                    HStack{
                        Text("Select group").appFont(.caption)
                        Spacer()
                        Button("Apply")
                        {
                            AppLog.write("GroupProperties sheet -> Select existing apply",model.groupName)
                            
                            if let theCamera = model.camera{
                                //this is a new group
                                model.changeListener?.moveCameraToGroup(camera: theCamera, grpName: model.groupName)
                                model.dimissListener?.dismissSheet()
                            }
                            
                        }
                        .disabled(model.applyEnabled == false)
                        .foregroundColor(.accentColor)
                        .appFont(.helpLabel)
                    }
                }
            }
            
            if let grp = model.group{
                if grp.name != CameraGroup.DEFAULT_GROUP_NAME{
                    Section(header: Text("Cameras in group").appFont(.sectionHeader)){
                        VStack(spacing: 5){
                            
                            ForEach(grp.cameras, id: \.self) { cam in
                                HStack{
                                    Text(cam.getDisplayName()).appFont(.caption)
                                    Text(cam.getDisplayAddr()).appFont(.caption)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            
        }.frame(alignment: .leading)
            .interactiveDismissDisabled()
        
    }
}


