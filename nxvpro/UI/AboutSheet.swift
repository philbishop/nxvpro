//
//  AboutSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 21/02/2022.
//

import SwiftUI

class AboutViewModel : ObservableObject{
    @Published var version: String = "6.1.0"
    @Published var iconSize =  CGFloat(20)
    
    var resetEnabled = true
   
}

struct AboutSection : View {
    var title: String
    var icon: String
    var detail: String
    var iconSize: CGFloat
    
    
    init(title: String,icon: String,detail: String,iconSize: CGFloat){
        self.title = title
        self.icon = icon
        self.detail = detail
        self.iconSize = iconSize
    }
    
    var body: some View {
       
        HStack{
            if icon.isEmpty == false {
                Image(systemName: icon).resizable().frame(width: iconSize,height: iconSize)
                Text(title).appFont(.caption)
            }else{
                Text(title).fontWeight(.semibold).appFont(.caption)
            }
        
            Text(detail).appFont(.smallCaption)
            Spacer()
        }.padding()
    }
}

struct AboutSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = AboutViewModel()
    
    @State var showResetAlert = false
    var body: some View {
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
            AboutSection(title: "Developer:", icon: "", detail: "Philip Bishop",iconSize: model.iconSize)
            AboutSection(title: "Contact:", icon: "", detail: "service,team@nx-v.uk",iconSize: model.iconSize)
            
            AboutSection(title: "App info:", icon: "", detail: "Version: " + model.version,iconSize: model.iconSize)
            
            HStack{
                Spacer()
                Button("Clear cache",action:{
                    showResetAlert = true
                }).appFont(.helpLabel).hidden(model.resetEnabled==false)
                    .alert(isPresented: $showResetAlert) {
                        
                        Alert(title: Text("Clear cached files created by NX-V"),
                              message: Text("Delete cached files?"),
                              
                              primaryButton: .default (Text("Delete")) {
                                showResetAlert = false
                                
                                globalCameraEventListener?.clearCache()
                                presentationMode.wrappedValue.dismiss()
                              },
                              secondaryButton: .cancel() {
                                showResetAlert = false
                              }
                        )
                    }.padding(.trailing)
            
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
            }
            /*
            ZStack(alignment: .top){
                Color(UIColor.secondarySystemBackground)
                HStack{
                    Spacer()
                    VStack(alignment: .leading){
                        
                        AboutSection(title: "App info", icon: "", detail: "Version: " + model.version,iconSize: model.iconSize)
                    }
                }
            }
             */
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
