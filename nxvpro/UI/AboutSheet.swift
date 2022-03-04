//
//  AboutSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 21/02/2022.
//

import SwiftUI

class AboutViewModel : ObservableObject{
    @Published var version: String = "6.1.0"
    @Published var iconSize =  CGFloat(16)
    
    var resetEnabled = true
    
}

struct AboutSection : View {
    var title: String
    var icon: String
    var detail: String
    var iconSize: CGFloat
    var isLink: Bool
    
    init(title: String,icon: String,detail: String,iconSize: CGFloat,isLink: Bool = false){
        self.title = title
        self.icon = icon
        self.detail = detail
        self.iconSize = iconSize
        self.isLink = isLink
    }
    
    var body: some View {
        
        HStack{
            if icon.isEmpty == false {
                Image(systemName: icon).resizable().frame(width: iconSize,height: iconSize).padding(.trailing,5)
                Text(title).appFont(.caption)
            }else{
                Text(title).fontWeight(.semibold).appFont(.caption)
                   
            }
            
            Text(detail).appFont(.smallCaption)
            Spacer()
        }
        .foregroundColor(isLink ? Color.accentColor : Color(UIColor.label))
        .padding()
    }
}

struct AboutSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = AboutViewModel()
    
    @State var showResetAlert = false
    @State var showResetCacheAlert = false
    var body: some View {
        VStack{
            List{
                HStack{
                    Text("About NX-V PRO").appFont(.title)
                        .padding()
                    
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    })
                    {
                        Image(systemName: "xmark").resizable()
                            .frame(width: 18,height: 18)
                    }
                }
                AboutSection(title: "Developer:", icon: "person", detail: "Philip Bishop",iconSize: model.iconSize)
                AboutSection(title: "Contact:", icon: "mail", detail: "service.team@nx-v.uk",iconSize: model.iconSize,isLink: true).onTapGesture {
                    let to = "service.team@nx-v.uk"
                    let subject = "NX-V PRO iPad"
                    let mailTo = "mailto:"+to+"?subject="+subject.replacingOccurrences(of: " ", with: "%20")
                    if let defaultUrl = URL(string: mailTo){
                        if  UIApplication.shared.canOpenURL(defaultUrl){
                            //presentationMode.wrappedValue.dismiss()
                            DispatchQueue.main.async{
                                UIApplication.shared.openURL(defaultUrl)
                            }
                        }
                    }
                }
                
                AboutSection(title: "App info:", icon: "info", detail: "Version: " + model.version,iconSize: model.iconSize)
            }
            HStack(spacing: 25){
               
                Button("Clear cache",action:{
                    showResetCacheAlert = true
                }).appFont(.helpLabel).hidden(model.resetEnabled==false)
                    .alert(isPresented: $showResetCacheAlert) {
                        
                        Alert(title: Text("Clear cached files created by NX-V"),
                              message: Text("Delete cached files?"),
                              
                              primaryButton: .default (Text("Delete")) {
                            showResetCacheAlert = false
                            
                            globalCameraEventListener?.clearCache()
                            presentationMode.wrappedValue.dismiss()
                        },
                              secondaryButton: .cancel() {
                            showResetCacheAlert = false
                        }
                        )
                    }
                
                Button("Clear application storage",action:{
                    showResetAlert = true
                }).appFont(.helpLabel).hidden(model.resetEnabled==false)
                    .alert(isPresented: $showResetAlert) {
                        
                        Alert(title: Text("Clear storage"),
                              message: Text("Delete ALL NX-V settings and files?"),
                              
                              primaryButton: .default (Text("Delete")) {
                            showResetAlert = false
                            
                            globalCameraEventListener?.clearStorage()
                            presentationMode.wrappedValue.dismiss()
                        },
                              secondaryButton: .cancel() {
                            showResetAlert = false
                        }
                        )
                    }
            }.padding()
            
        }.onAppear(){
            model.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        }
        
    }
    
}

struct AboutSheet_Previews: PreviewProvider {
    static var previews: some View {
        AboutSheet()
    }
}
