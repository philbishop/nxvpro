//
//  NXTabItem.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI

class TabbedViewHeaderModel : ObservableObject{
    var listener: NXTabSelectedListener?
    @Published var selectedHeader = ""
    @Published var storageSegHeaders = ["Local (NX-V)","Onboard","Remote","iCloud (NX-V)"]
    
    func checkAvailable(){
        if cloudStorage.iCloudAvailable == false{
            storageSegHeaders = ["Local (NX-V)","Onboard","Remote"]
        }else{
            storageSegHeaders = ["Local (NX-V)","Onboard","Remote","iCloud (NX-V)"]
        }
    }
}

class NXTabItemModel : ObservableObject{
    @Published var name = ""
    @Published var isSelected = false
    @Published var backgroundColor = Color(UIColor.secondarySystemBackground)
    @Published var borderColor: Color = .accentColor
    
    @Published var borderWThickness = CGFloat(0.0)
    @Published var tabWidth = CGFloat(85)
    @Published var fontWieght = Font.Weight.regular
    func setSelected(selected: Bool){
        if selected{
            backgroundColor = Color(UIColor.tertiarySystemBackground)
            borderWThickness = CGFloat(1.0)
            borderColor = .accentColor
            fontWieght = Font.Weight.regular
        }else{
            backgroundColor = Color(UIColor.secondarySystemBackground)
            borderColor = Color(UIColor.label)
            borderWThickness = CGFloat(0.5)
            fontWieght = Font.Weight.light
        }
    }
}

struct NXTabItem: View {
    
    @ObservedObject var model = NXTabItemModel()
    
    func setName(name: String){
        model.name = name
    }
    
    init(name: String, selected: Bool = false,tabWidth: Int = 85){
        self.model.name = name
        self.model.tabWidth = CGFloat(tabWidth)
        self.model.setSelected(selected: selected)
    }
    
    var body: some View {
        
       
        ZStack{
            model.backgroundColor
            Text(model.name)
                .font(.system(size: 14, weight: model.fontWieght, design: .default))
        
            /*
                .padding(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(model.borderColor, lineWidth: model.borderWThickness)
                )
            */
              
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(model.borderColor, lineWidth: model.borderWThickness)
        )
        //.border(model.borderColor, width: model.borderWThickness)
        //.cornerRadius(5.0)
        //.frame(width:model.tabWidth,height: 28)
        .frame(height: 22)
       
           
        
    }
}

struct NXTabItem_Previews: PreviewProvider {
    static var previews: some View {
        NXTabItem(name: Camera.DEFAULT_TAB_NAME,selected: true)
    }
}
