//
//  ProHelpView.swift
//  nxvpro
//
//  Created by Philip Bishop on 05/03/2022.
//

import SwiftUI

class ProHelpModel : ObservableObject{
    @Published var helpText: String = "No help available"
    @Published var lines: [Tag] = [Tag]()
    @Published var title = ""
    
    func setContext(res: String){
        setTextForResource(res: res)
    }
    func setTextForResource(res: String){
        if let filepath = Bundle.main.path(forResource: res, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                //print(contents)
                helpText = contents
                lines.removeAll()
                let theLines = contents.components(separatedBy: "\n")
                for i in 0...theLines.count-1 {
                    let line = theLines[i]
                    lines.append(Tag(line: line,id: i))
                }
            } catch {
                print("HelpContext: \(error)")
            }
        }else{
            print("HelpContext: Can't find",res)
        }
    }
}

struct ProHelpItemView: View {
    var text: String
    
    init(_ text: String){
        self.text = text
    }
    
    var body: some View {
        HStack{
            Text(text).appFont(.caption)
            Spacer()
        }
    }
}

struct ProNavTabHelp : View{
    @ObservedObject var model = ProHelpModel()
    
    init(title: String,res: String){
        model.title = title
        model.setContext(res: res)
    }
    
    var body: some View {
        VStack{
           
            Text(model.title).appFont(.smallTitle)
            ScrollView(.vertical){
            ForEach( model.lines, id: \.self) { tag in
                let line = tag.line
                if line.hasPrefix("<b>"){
                    let ln = line.replacingOccurrences(of: "<b>", with: "")
                    BulletItemView(line: ln).padding(.leading)
                }else{
                    ProHelpItemView(line).padding(.leading)
                }
            }
            }
            Spacer()
        }
    }
}
/*
struct ProCameraTabHelp : View{
    @ObservedObject var model = ProHelpModel()
    
   init(){
        model.setContext(res: "pro_cam_tabs")
    }
    var body: some View {
        VStack(){
            Text("Camera tabs").appFont(.smallTitle)
            ScrollView(.vertical){
                ForEach( model.lines, id: \.self) { tag in
                    let line = tag.line
                    if line.hasPrefix("<b>"){
                        let ln = line.replacingOccurrences(of: "<b>", with: "")
                        BulletItemView(line: ln).padding()
                    }else{
                        ProHelpItemView(line).padding(.leading)
                    }
                }
            }
            Spacer()
        }
    }
*/
struct ProHelpView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var navTabs = ProNavTabHelp(title: "Navigation tabs",res: "pro_cameras")
    var camTabs = ProNavTabHelp(title: "Camera tabs",res: "pro_cam_tabs")
    
    var body: some View {
        ZStack(){
            VStack{
                HStack{
                    Text("Help").appFont(.smallTitle)
                        .padding()
                    
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    })
                    {
                        Image(systemName: "xmark").resizable()
                            .frame(width: 16,height: 16)
                    }.foregroundColor(Color.accentColor)
                        .padding(.trailing)
                }.cornerRadius(0.15)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                .padding(0)
                
            GeometryReader { fullView in
                let ctrlSize = (fullView.size.width / 2) - 10
               
                    
                    HStack{
                        navTabs.frame(width: ctrlSize)
                        Divider()
                        camTabs.frame(width: ctrlSize)
                    }
                }
            }
        }
    }
}

struct ProHelpView_Previews: PreviewProvider {
    static var previews: some View {
        ProHelpView()
    }
}

