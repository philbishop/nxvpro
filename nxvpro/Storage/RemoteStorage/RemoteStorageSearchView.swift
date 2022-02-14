//
//  RemoteStorageSearchView.swift
//  NX-V
//
//  Created by Philip Bishop on 27/01/2022.
//

import SwiftUI



protocol RemoteStorageActionListener{
    func doSearch(camera: Camera,date: Date,useCache: Bool)
}
protocol RemoteSearchCompletionListener{
    func onRemoteSearchComplete(success: Bool,status: String)
}
protocol RemoteStorageTransferListener{
    func doDownload(token: RecordToken)
    func doPlay(token: RecordToken)
}

class RemoteStorageModel : ObservableObject, RemoteSearchCompletionListener{
    @Published var date: Date
    //@Published var startDate: Date?
    //@Published var endDate: Date
    @Published var searchDisabled = false
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
        searchStatus = "Searching..."
        listener?.doSearch(camera: camera!,date: date, useCache: useCache)
    }
    
    
    
    
    func onRemoteSearchComplete(success: Bool, status: String) {
        print("RemoteStorageModel:onRemoteSearchComplete",status,success)
        DispatchQueue.main.async{
            self.searchStatus = status
        }
    }
}

struct RemoteStorageSearchView: View, StorageSettingsChangedListener {

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
                
                Text("Date")
                DatePicker("", selection: $model.date, displayedComponents: .date).frame(width: 150)
                
                Button(action: {
                    print("Search date",model.date)
                    model.doSearch(useCache: true)
                }){
                    Image(systemName: "magnifyingglass").resizable().frame(width: 18,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.searchDisabled)
                
                Button(action: {
                    print("REFRESH date",model.date)
                    model.doSearch(useCache: false)
                }){
                    Image(systemName: "arrow.triangle.2.circlepath").resizable().frame(width: 20,height: 18)
                }.buttonStyle(PlainButtonStyle()).disabled(model.refreshDisabled || model.searchDisabled)
                   
                
                Spacer()
                Text(model.searchStatus)
            }
        }.padding()
            
    }
}


struct RemoteStorageConfigView : View{
    
     
     
    var ftpSettingsView = FtpSettingsView2()
    
    func setCamera(camera: Camera,changeListener: StorageSettingsChangedListener){
        
    
        ftpSettingsView.model.setCamera(camera: camera,changeListener: changeListener)
    }
    
    var body: some View {
        List(){
           Section(header: Text("Configuration")){
               ftpSettingsView
           }
       }.listStyle(PlainListStyle()).frame(height: 120)
      
    }
}
    
