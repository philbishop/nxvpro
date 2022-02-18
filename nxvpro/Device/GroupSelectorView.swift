//
//  GroupSelectorView.swift
//  NX-V
//
//  Created by Philip Bishop on 09/09/2021.
//

import SwiftUI

protocol GroupChangedListener{
    func moveCameraToGroup(camera: Camera,grpName: String) -> [String]
}

class GroupSelectorModel : ObservableObject {
    @Published var groupName: String = ""
    @Published var groups: [String] = [String]()
    @Published var applyDisabled = true
    @Published var showGroupSheet = false
    
   
    var newGroup: CameraGroup?
    var grpChangeListener: GroupChangedListener?
    
    func createNewGroup(camera: Camera){
        newGroup = CameraGroup()
        let ng = newGroup!
        ng.name = "Group " + String(groups.count)
        ng.cameras.append(camera)
   }
}
struct GroupSelectorView: View, NXSheetDimissListener {
    
    @ObservedObject var model = GroupSelectorModel()
    var existingGrp: String
    var camera: Camera?
    
    
    init(camera: Camera?,groups: [String],existingGrp: String){
       
        self.camera = camera
        self.existingGrp = existingGrp
       
        model.groupName = existingGrp
        model.groups = groups
    }
    
    func setListener(listener: GroupChangedListener){
        model.grpChangeListener = listener
    }
    
    
    
    //MARK: NXSheetDimissListener
    func dismissSheet() {
        model.showGroupSheet = false
    }
    
    var body: some View {
        HStack{
            Picker("", selection: $model.groupName) {
                ForEach(self.model.groups, id: \.self) {
                    Text($0).foregroundColor(Color(UIColor.label)).appFont(.caption)
                        
                }.onChange(of: model.groupName) { newName in
                    if newName == "New group"{
                        model.createNewGroup(camera: self.camera!)
                        model.showGroupSheet = true
                    }else{
                        //change the group
                        model.applyDisabled = newName == existingGrp
                        model.grpChangeListener?.moveCameraToGroup(camera: self.camera!, grpName: newName)
                    }
                }
            }.pickerStyle(SegmentedPickerStyle())
            
            Spacer()
            
        }.sheet(isPresented: $model.showGroupSheet) {
            model.showGroupSheet = false
        } content: {
            GroupPropertiesSheet(camera: self.camera!,group: model.newGroup!,listener: self,changeListener: model.grpChangeListener!)
        }

    }
}


