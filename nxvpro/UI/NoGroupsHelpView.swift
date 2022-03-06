//
//  NoGroupsHelpView.swift
//  NX-V
//
//  Created by Philip Bishop on 17/10/2021.
//

import SwiftUI

struct BulletItemView: View {
    var line: String
    var bulletSize = CGFloat(9)
    
    init(line: String,isSmall: Bool = false){
        self.line = line
        if isSmall{
            bulletSize = CGFloat(4.5)
        }
    }
    
    var body: some View {
        HStack{
            Image(systemName: "circle.fill").resizable().frame(width: bulletSize, height: bulletSize)
    
            Text(line).appFont(.caption)
            
            Spacer()
        }
    }
}

struct NoGroupsHelpView: View {
    var body: some View {
        ZStack(alignment: .top){
            Color(UIColor.secondarySystemBackground)
            VStack(alignment: .leading,spacing: 10){
                Text("No cameras assigned to groups").font(Font.system(.caption).smallCaps())
                
                Text("CREATING GROUPS").fontWeight(.semibold).appFont(.sectionHeader)
                BulletItemView(line: "Select a camera in main list")
                BulletItemView(line: "Camera details tab")
                BulletItemView(line: "Group")
                BulletItemView(line: "Select New Group")
                BulletItemView(line: "Click Add to Group")
                Text("USING GROUPS").fontWeight(.semibold).appFont(.sectionHeader)
                HelpIconLabel(line: "!!play Group multicam view",withTheme: true)
                Text("Click to view only the selected cameras in the group").appFont(.caption)
                
            }.padding(10)
        }.cornerRadius(15).frame(width: 230,height: 320).padding(10)
        
    }
}

struct NoGroupsHelpView_Previews: PreviewProvider {
    static var previews: some View {
        NoGroupsHelpView()
    }
}
