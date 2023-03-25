//
//  FtpSettingsSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 10/03/2022.
//

import SwiftUI

protocol FtpSettingsAuthListener{
    func onFtpAuthenticated(ss: StorageSettings)
}

struct FtpSettingsSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = FtpSettingsModel()
    
    
    func setCamera(camera: Camera,listener: StorageSettingsChangedListener,authListener: FtpSettingsAuthListener){
        
        model.setCamera(camera: camera, changeListener: listener)
        model.authListener = authListener
    }
    
    var body: some View {
       
        //List(){
        VStack(alignment: .leading,spacing: 10){
            VStack (alignment: .leading){
                HStack{
                    VStack{
                        Text("FTP Settings").appFont(.title)
                            .padding()
                    }
                    Spacer()
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                       
                    })
                    {
                        Image(systemName: "xmark").resizable()
                            .frame(width: 18,height: 18)
                    }.foregroundColor(Color.accentColor)
                }
                Text(model.camName).fontWeight(.light).appFont(.caption)
            }
            Form{
                Section(header: Text("Credentials").appFont(.sectionHeader)){
                    VStack(spacing: 0){
                        TextField("User",text: $model.user).autocapitalization(.none).padding()
                        
                        SecureInputView("Password",text: $model.password).appFont(.titleBar)
                            .autocapitalization(.none).padding()
                        
                    }
                    
                }
                
                Section(header: Text("Server host,port and mode").appFont(.sectionHeader)){
                    VStack(alignment: .leading,spacing: 10){
                        HStack{
                            TextField("Host",text: $model.host).autocapitalization(.none)
                            Spacer()
                            Text("Port").font(.body.weight(.ultraLight))
                            TextField("Port",text: $model.port).keyboardType(.numberPad)
                                .frame(width: 35,alignment: .trailing)
                        }
                        Picker("Mode",selection: $model.selectedMode){
                            ForEach(model.ftpModes, id: \.self) {
                                Text($0)
                            }
                        }.onChange(of: model.selectedMode) { newType in
                            model.selectedMode = newType
                        }.pickerStyle(.menu)
                        /*
                         Text("Folder")
                         if model.authenticated{
                         TextField("",text: $model.path)
                         }
                         //   Spacer()
                         */
                        Picker("Folder",selection: $model.path){
                            ForEach(model.dirs, id: \.self) {
                                Text($0)
                            }
                        }.onChange(of: model.path) { newPath in
                            model.path = newPath
                        }
                        .pickerStyle(.menu)
                        //.hidden(model.dirs.count == 0)
                        
                        
                        
                        //  }.hidden(model.statusHidden==false)
                    }
                }
                
                // HStack{
                
                // Spacer()
                Text("Check details").foregroundColor(model.verifyEnabled ?model.activeColor:model.noColor)
                    .padding(.trailing)
                    .onTapGesture {
                        if model.verifyEnabled{
                            model.doVerify()
                        }
                    }
               
                Text("Save").foregroundColor(model.saveEnabled ?model.activeColor:model.noColor)
                    .onTapGesture {
                        if model.saveEnabled{
                            model.saveSettings()
                        }
                    }
                
                //}
            }
            Text(model.status).fontWeight(.light)
                .appFont(.body)
        }.padding(20)
    }
}


struct FtpSettingsSheet_Previews: PreviewProvider {
    static var previews: some View {
        FtpSettingsSheet()
    }
}
 
