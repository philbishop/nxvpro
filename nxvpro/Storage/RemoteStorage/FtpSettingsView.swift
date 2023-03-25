//
//  FtpSettingsView.swift
//  NX-V
//
//  Created by Philip Bishop on 31/01/2022.
//

import SwiftUI
import FilesProvider

protocol StorageSettingsChangedListener{
    func storageSettingsChanged(camera: Camera)
}

class FtpSheetModel : ObservableObject{
    @Published var showSheet = false
    var settingsSheet = FtpSettingsSheet()
    @Published var displayDetails = ""
}

struct FtpSettingsView2: View, FtpSettingsAuthListener {
    @ObservedObject var model = FtpSettingsModel()
    @ObservedObject var sheetModel = FtpSheetModel()
    
    func onFtpAuthenticated(ss: StorageSettings) {
        sheetModel.showSheet = false
        
        sheetModel.displayDetails = ss.host+":"+ss.port+ss.path
        AppLog.write("onFtpAuthenticated",sheetModel.displayDetails)
        
        //update actual model
        model.updateStorageSettings(ss)
    }
    
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
        model.setCamera(camera: camera, changeListener: changeListener)
        sheetModel.settingsSheet.setCamera(camera: camera, listener: changeListener,authListener: self)
        sheetModel.displayDetails = ""
        if model.authenticated{
            sheetModel.displayDetails = model.host+":"+model.port+model.path
        }
        
    }
    func getHostAndPort() -> String{
        var hostAndPort = model.host
        if let iport = Int(model.port){
            hostAndPort = hostAndPort + ":" + model.port
        }
        return hostAndPort
    }
    func getCredentials() -> URLCredential{
        return URLCredential(user: model.user, password: model.password, persistence: .forSession)
    }
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                if sheetModel.displayDetails.isEmpty == false{
                    Text(sheetModel.displayDetails)
                            .padding()
                }
                Button("FTP settings"){
                    sheetModel.showSheet = true
                }.appFont(.body)
                .padding()
                Spacer()
            }.sheet(isPresented: $sheetModel.showSheet) {
                sheetModel.settingsSheet
            }

        }.padding(.leading,5)
    }
}
