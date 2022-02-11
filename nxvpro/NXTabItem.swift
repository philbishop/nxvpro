//
//  NXTabItem.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI

class NXTabItemModel : ObservableObject{
    @Published var isSelected = false
    @Published var backgroundColor = Color(UIColor.secondarySystemBackground)
    @Published var borderColor: Color = .accentColor
    
    @Published var borderWThickness = CGFloat(0.0)
    
    func setSelected(selected: Bool){
        if selected{
            backgroundColor = Color(UIColor.tertiarySystemBackground)
            borderWThickness = CGFloat(1.0)
            borderColor = .accentColor
        }else{
            backgroundColor = Color(UIColor.secondarySystemBackground)
            borderColor = Color(UIColor.label)
            borderWThickness = CGFloat(1)
        }
    }
}

struct NXTabItem: View {
    
    @ObservedObject var model = NXTabItemModel()
    
    var name: String
    
    init(name: String,selected: Bool = false){
        self.name = name
        self.model.setSelected(selected: selected)
    }
    
    var body: some View {
       
        ZStack{
            model.backgroundColor
            Text(self.name)//.font(.callout)
                .font(.system(size: 14, weight: .regular, design: .default))
        
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
        .frame(width:85,height: 28)
            
            
           
        
    }
}

struct NXTabItem_Previews: PreviewProvider {
    static var previews: some View {
        NXTabItem(name: "Cameras",selected: true)
    }
}
