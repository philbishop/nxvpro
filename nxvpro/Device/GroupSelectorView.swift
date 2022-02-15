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
    
    var grpChangeListener: GroupChangedListener?
}
struct GroupSelectorView: View {
    
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
    var body: some View {
        HStack{
            Picker("", selection: $model.groupName) {
                ForEach(self.model.groups, id: \.self) {
                    Text($0).foregroundColor(Color(UIColor.label)).appFont(.caption)
                        
                }.onChange(of: model.groupName) { newName in
                    model.applyDisabled = newName == existingGrp
                }
            }.pickerStyle(SegmentedPickerStyle())
            
            Spacer()
            Button("Add to group",action: {
                if let cam = camera{
                    if let newNames = model.grpChangeListener?.moveCameraToGroup(camera: cam, grpName: model.groupName){
                        for grp in newNames{
                            if model.groups.contains(grp){
                                continue
                            }
                            model.groups.append(grp)
                        }
                        
                    }
                    
                }
            }).appFont(.caption)
                .buttonStyle(PlainButtonStyle())
                .disabled(model.applyDisabled)
        }
    }
}


