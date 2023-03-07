//
//  RemoteStorageSearchView.swift
//  NX-V
//
//  Created by Philip Bishop on 27/01/2022.
//

import SwiftUI



protocol RemoteStorageActionListener{
    func doSearch(camera: Camera,date: Date,useCache: Bool)
    func searchComplete()
}
protocol RemoteSearchCompletionListener{
    func onRemoteSearchComplete(success: Bool,status: String)
}
protocol RemoteStorageTransferListener{
    func doDownload(token: RecordToken)
    func doPlay(token: RecordToken)
    func doDelete(token: RecordToken)
}

class RemoteStorageModel : ObservableObject, RemoteSearchCompletionListener{
    @Published var date: Date
    //iOS 16
    @Published var dateScale = 1.0
    func checkDynamicTypeSize(sizeCategory: DynamicTypeSize){

        switch sizeCategory{
        case .accessibility2:
            self.dateScale = 0.6
            break;
        case.accessibility3:
            self.dateScale = 0.5
            break;
            
        case.accessibility4:
            self.dateScale = 0.4
            break;
        case.accessibility5:
            self.dateScale = 0.3
            break;
        default:
            self.dateScale = 1.0
            break
        }
    }
    
    //@Published var endDate: Date
    @Published var searchDisabled = true
    @Published var refreshDisabled = true
    @Published var searchStatus: String
   
    
    var listener: RemoteStorageActionListener?
    var camera: Camera?
    
    init(){
        date = Calendar.current.startOfDay(for: Date())
       // startDate = Calendar.current.startOfDay(for: Date())
        //endDate = Calendar.current.startOfDay(for: Date())
        searchStatus = "Select date and click search button"
    }
    
    func doSearch(useCache: Bool){
        if let cam = camera{
            let ss = cam.storageSettings
            if ss.authenticated == false{
                searchStatus = "Not configured"
                searchDisabled = true
                return
            }
        }
        searchStatus = "Searching..."
        searchDisabled = true
        listener?.doSearch(camera: camera!,date: date, useCache: useCache)
    }
    
    
    
    
    func onRemoteSearchComplete(success: Bool, status: String) {
        AppLog.write("RemoteStorageModel:onRemoteSearchComplete",status,success)
        DispatchQueue.main.async{
            self.searchDisabled = !success
            self.searchStatus = status
        }
    }
}

struct RemoteStorageSearchView: View, StorageSettingsChangedListener {

    @Environment(\.dynamicTypeSize) var sizeCategory
    @ObservedObject var model = RemoteStorageModel()
    
    func setCamera(camera: Camera,listener: RemoteStorageActionListener){
        model.listener = listener
        model.camera = camera
        model.searchDisabled = camera.storageSettings.authenticated == false
    }
    func storageSettingsChanged(camera: Camera) {
        model.searchDisabled = camera.storageSettings.authenticated == false
    }
    var body: some View {
        VStack{
            HStack{
                
                Text("Date").appFont(.caption).padding(.leading)
                DatePicker("", selection: $model.date, displayedComponents: .date)
                    .appFont(.caption)
                    .scaleEffect(model.dateScale)
                    .disabled(model.searchDisabled)
                    .frame(width: 150)
                
                Button(action: {
                    AppLog.write("Search date",model.date)
                    model.doSearch(useCache: true)
                }){
                    Image(systemName: "magnifyingglass").resizable().frame(width: 18,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.searchDisabled)
                
                /*
                Button(action: {
                    AppLog.write("REFRESH date",model.date)
                    model.doSearch(useCache: false)
                }){
                    Image(systemName: "arrow.triangle.2.circlepath").resizable().frame(width: 20,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.refreshDisabled || model.searchDisabled)
                  */
                
                Spacer()
                Text(model.searchStatus).appFont(.caption)
                    .padding(.trailing,25)
            }
        }.padding(0)
            .onAppear{
                model.checkDynamicTypeSize(sizeCategory: sizeCategory )
            }
            
    }
}

class RemoteStorageConfigModel : ObservableObject{
    //@Published var storageTypes = ["FTP","SMB/CIF","NFS"]
    @Published var selectedType = "FTP"
    var st = ["ftp","smb","nfs"]
    
    func getStorageType() -> String{
        
        /*
        for i in 0...storageTypes.count-1{
            if storageTypes[i] ==  selectedType{
                return st[i]
            }
        }
         */
        return "ftp"
    }
    func setStorageType(ss: StorageSettings){
        /*
        for i in 0...st.count-1{
            if st[i] ==  ss.storageType{
                selectedType = storageTypes[i]
            }
        }
        */
    }
}

struct RemoteStorageConfigView : View{
    @ObservedObject var model = RemoteStorageConfigModel()
    
    var ftpSettingsView = FtpSettingsView2()
    
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
        let ss = camera.storageSettings
        model.setStorageType(ss: ss)
        ftpSettingsView.setCamera(camera: camera,changeListener: changeListener)
    }
    
    var body: some View {
        VStack{
            /*
            Picker("Type",selection: $model.selectedType){
                ForEach(model.storageTypes, id: \.self) {
                    let st = $0
                    Text(st)
                }
            }.onChange(of: model.selectedType) { newType in
                model.selectedType = newType
                if newType == "FTP"{
                    ftpSettingsView.model.showPort = true
                    ftpSettingsView.model.port = "21"
                }else{
                    ftpSettingsView.model.showPort = false
                    ftpSettingsView.model.port = "n/a"
                }
                ftpSettingsView.model.saveEnabled = false
            }.pickerStyle(SegmentedPickerStyle())
            */
             ftpSettingsView
        }
        /*
        List(){
           Section(header: Text("Configuration")){
               ftpSettingsView
           }
       }.listStyle(PlainListStyle()).frame(height: 180)
      */
    }
}
    
