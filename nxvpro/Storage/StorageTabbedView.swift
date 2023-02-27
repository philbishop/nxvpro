//
//  StorageTabbedView.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI



struct StorageTabHeaderAltView : View{
    @ObservedObject var model = TabbedViewHeaderModel()
    
    var tabHeight = CGFloat(32.0)
    var dummyTab = NXTabItem(name: "")
    init(){
        model.selectedHeader = model.storageSegHeaders[0]
    }
    
    func checkTabHeaders(){
        model.checkAvailable()
    }
    
    func setListener(listener: NXTabSelectedListener){
        model.listener = listener
    }
    func segSelectionChanged(){
        if let callback = model.listener{
            if model.selectedHeader == model.storageSegHeaders[0]{
                callback.tabSelected(tabIndex: 0, source: dummyTab)
            }else if model.selectedHeader == model.storageSegHeaders[1]{
                callback.tabSelected(tabIndex: 1, source: dummyTab)
            }else if model.selectedHeader == model.storageSegHeaders[2]{
                callback.tabSelected(tabIndex: 2, source: dummyTab)
            }else if model.selectedHeader == model.storageSegHeaders[3]{
                callback.tabSelected(tabIndex: 3, source: dummyTab)
            }
        }
    }
    var body: some View {
        HStack(spacing: 7){
            
            //tab view
            Picker("", selection: $model.selectedHeader) {
                ForEach(model.storageSegHeaders, id: \.self) {
                    Text($0)
                }
            }.onChange(of: model.selectedHeader) { tabItem in
                segSelectionChanged()
            }.pickerStyle(SegmentedPickerStyle())
                .fixedSize()
           
            Spacer()
        }.frame(height: tabHeight)
            .onAppear{
                model.checkAvailable()
            }
    }
}


class StorageTabbedViewModel : ObservableObject{
    @Published var selectedTab = 0
    var onBoardView = SdCardView()
}

struct StorageTabbedView : View, NXTabSelectedListener{
    
    @ObservedObject var model = StorageTabbedViewModel()
    
    let tabHeader = StorageTabHeaderAltView()
    let onDeviceView = OnDeviceStorageView()
    let iCloudView = iCloudSearchView()
    let remoteView = FtpStorageView()
    let sharedView = SharedStorageView()
    
    //MARK: NXTabSelectedListener
    func tabSelected(tabIndex: Int, source: NXTabItem) {
        model.selectedTab = tabIndex
    }
    func touchOnDevice(){
        model.selectedTab = 1
        model.selectedTab = 0
    }
    func setCamera(camera: Camera){
        onDeviceView.setCamera(camera: camera)
        remoteView.setCamera(camera: camera)
        iCloudView.setCamera(camera: camera)
        
        tabHeader.checkTabHeaders()
        
        model.onBoardView = SdCardView()
        
        if camera.searchXAddr.isEmpty{
            model.onBoardView.setCamera(camera: camera,recordRange: nil)
        }else if camera.isVirtual{
            model.onBoardView.setStatus(status: "Storage interface available at NVR level only")
            
        } else{
            model.onBoardView.setStatus(status: "Loading event data, please wait...")
            DispatchQueue.main.async{
                getStorageRange(camera: camera)
            }
        }
        
    }
    var body: some View {
        VStack{
            tabHeader
            ZStack(alignment: .topLeading){
                
                onDeviceView.hidden(model.selectedTab != 0)
               
                model.onBoardView.hidden(model.selectedTab != 1)
                
                remoteView.hidden(model.selectedTab != 2)
                
                iCloudView.hidden(model.selectedTab != 3)
                //shared not possible to list files?
                //sharedView.hidden(model.selectedTab != 3)
            }
            
        }.background(Color(uiColor: .secondarySystemBackground))
        .onAppear {
            tabHeader.setListener(listener: self)
        }
    }
    
    private func getStorageRange(camera: Camera){
        let disco = OnvifSearch()
        disco.searchForVideoDateRange(camera: camera) { camera, ok, error in
            DispatchQueue.main.async{
                if ok{
                    model.onBoardView.setStatus(status: "")
                    if camera.recordingProfile == nil{
                        let recordRange = disco.getProfile(camera: camera)
                        camera.recordingProfile = recordRange
                    }
                    if let rp = camera.recordingProfile{
                        model.onBoardView.setCamera(camera: camera, recordRange: rp)
                    }
                    
                }else{
                    //set status on sdcard
                    var errorStr = error
                    if error.isEmpty{
                        errorStr = "Failed to complete: " + error
                    }
                    model.onBoardView.setStatus(status: errorStr)
                }
            }
        }
    }
}
