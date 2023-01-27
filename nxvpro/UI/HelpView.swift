//
//  HelpView.swift
//  NX-V
//
//  Created by Philip Bishop on 02/06/2021.
//

import Foundation

import SwiftUI

struct Tag: Identifiable,Hashable {
    let id: Int
    var line: String
    
    init(line: String,id: Int){
        self.id = id
        self.line=line
    }
    //MARK: Hashable
    func hash(into hasher: inout Hasher) {
            hasher.combine(id)
    }
}

class ContextHelpModel : ObservableObject{
    @Published var helpText: String = "No help available"
    @Published var lines: [Tag] = [Tag]()
    @Published var height = CGFloat(475)
    
    func setContext(contextId: Int){
        var res = "help_disco"
        height = CGFloat(475)
        switch contextId{
        case 1:
            height = CGFloat(425)
            res = "help_vmd"
            break
        case 2:
            height = CGFloat(455)
            res = "help_ptz"
            break
        case 3:
            res = "help_favs"
            break
        default:
            break
        }
        
        setTextForResource(res: res)
    }
    func setTextForResource(res: String){
        if let filepath = Bundle.main.path(forResource: res, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                //AppLog.write(contents)
                helpText = contents
                lines.removeAll()
                let theLines = contents.components(separatedBy: "\n")
                for i in 0...theLines.count-1 {
                    let line = theLines[i]
                    lines.append(Tag(line: line,id: i))
                }
            } catch {
                AppLog.write("HelpContext: \(error)")
            }
        }else{
            AppLog.write("HelpContext: Can't find",res)
        }
    }
}

struct HelpIconLabel : View {
    
    @Environment(\.colorScheme) var colorScheme
    var line: String
    var withTheme: Bool
    init(line: String,withTheme: Bool){
        self.line = line
        self.withTheme = withTheme
    }
    var body: some View {
        let parts = line.components(separatedBy: " ")
        let iconName = parts[0].replacingOccurrences(of: (withTheme ? "!!" : "!>"), with: "") + (withTheme ? (colorScheme == .dark ? "_dark" : "_light" ) : "" )
        
        let txt = line.replacingOccurrences(of: parts[0], with: "")
        
        HStack(spacing: 1){
            Image(iconName).resizable().frame(width: 22,height: 22)
            Text(txt).fontWeight(.bold).lineLimit(nil).appFont(.helpLabel)
        }
    }
}


protocol ContextHelpViewListener{
    func onCloseHelp()
}

class ContextHelpViewModel: ObservableObject{
    var listener: ContextHelpViewListener?
}

struct ContextHelpView: View {
    
    @ObservedObject var helpContext = ContextHelpModel()
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var model = ContextHelpViewModel()
    
    
    func setContext(contextId: Int,listener: ContextHelpViewListener?){
        helpContext.setContext(contextId: contextId)
        model.listener = listener
    }
    
    init(){
        helpContext.setContext(contextId: 0)
    }
    
    var body: some View {
        VStack{//}(alignment: .top){
            //Color(UIColor.secondarySystemBackground)
            ScrollView{
            VStack(alignment: .leading,spacing: 0){
                ForEach( helpContext.lines, id: \.self) { tag in
                    let line = tag.line
                    if line.hasPrefix("#"){
                        let ln = line.replacingOccurrences(of: "#", with: "")
                        Text(ln).fontWeight(.semibold).appFont(.caption)
                    }else if(line.hasPrefix("!!")){
                        
                        HelpIconLabel(line: line,withTheme: true)
                    }else if(line.hasPrefix("!>")){
                       
                        HelpIconLabel(line: line,withTheme: false)
                    }else {
                        
                        Text(line).lineLimit(nil).appFont(.caption)
                    }
                }
                Spacer()
            }
             Spacer()
                HStack{
                    Spacer()
                    
                    Button(action: {
                        model.listener?.onCloseHelp()
                    }){
                        Text("Close")
                    }.appFont(.body)
                }
            }.padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15).frame(width: 220,height: helpContext.height).padding(10).onAppear(){
            AppLog.write("HelpView:onAppear()")
        }
        
    }
    
}

struct ContextHelpView_Previews: PreviewProvider {
    static var previews: some View {
        ContextHelpView()
    }
}
