//
//  StorageTabbedView.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI



struct StorageTabHeaderView : View{
    
    @ObservedObject var model = TabbedViewHeaderModel()
    
    @State var onDeviceTab = NXTabItem(name: "Local (NX-V)",selected: true)
    @State var onBoardTab = NXTabItem(name: "Onboard",selected: false)
    @State var remoteTab = NXTabItem(name: "FTP",selected: false)
    @State var sharedTab = NXTabItem(name: "Shared",selected: false)
    
    func setListener(listener: NXTabSelectedListener){
        model.listener = listener
    }
    private func tabSelected(tabIndex: Int){
        onDeviceTab.model.setSelected(selected: tabIndex==0)
        onBoardTab.model.setSelected(selected: tabIndex==1)
        remoteTab.model.setSelected(selected: tabIndex==2)
        sharedTab.model.setSelected(selected: tabIndex==3)
        if let callback = model.listener{
            if tabIndex == 0{
                callback.tabSelected(tabIndex: 0, source: onDeviceTab)
            }else if tabIndex == 1{
                callback.tabSelected(tabIndex: 1, source: onBoardTab)
            }else if tabIndex == 2{
                callback.tabSelected(tabIndex: 2, source: remoteTab)
            }else if tabIndex == 3{
                callback.tabSelected(tabIndex: 3, source: sharedTab)
            }
        }
    }
    
    var body: some View {
        
        HStack(spacing: 7){
            Spacer()
            onDeviceTab
                .onTapGesture {
                    tabSelected(tabIndex: 0)
                }
            onBoardTab.onTapGesture {
                tabSelected(tabIndex: 1)
            }
            remoteTab.onTapGesture {
                tabSelected(tabIndex: 2)
            }
            /*
            sharedTab.onTapGesture {
                tabSelected(tabIndex: 3)
            }
             */
            Spacer()
        }
    }
}

class StorageTabbedViewModel : ObservableObject{
    @Published var selectedTab = 0
}

struct StorageTabbedView : View, NXTabSelectedListener{
    
    @ObservedObject var model = StorageTabbedViewModel()
    
    let tabHeader = StorageTabHeaderView()
    let onDeviceView = OnDeviceStorageView()
    let onBoardView = SdCardView()
    let remoteView = FtpStorageView()
    let sharedView = SharedStorageView()
    
    //MARK: NXTabSelectedListener
    func tabSelected(tabIndex: Int, source: NXTabItem) {
        model.selectedTab = tabIndex
    }
    
    func setCamera(camera: Camera){
        onDeviceView.setCamera(camera: camera)
        if camera.searchXAddr.isEmpty{
            onBoardView.setCamera(camera: camera,recordRange: nil)
        }else{
            onBoardView.setStatus(status: "Loading event data, please wait...")
            getStorageRange(camera: camera)
        }
        remoteView.setCamera(camera: camera)
    }
    var body: some View {
        VStack{
            tabHeader
            ZStack(alignment: .topLeading){
                
                onDeviceView.hidden(model.selectedTab != 0)
               
                onBoardView.hidden(model.selectedTab != 1)
                
                remoteView.hidden(model.selectedTab != 2)
                
                //shared not possible to list files?
                //sharedView.hidden(model.selectedTab != 3)
            }
            
        }.onAppear {
            tabHeader.setListener(listener: self)
        }
    }
    
    private func getStorageRange(camera: Camera){
        let disco = OnvifSearch()
        disco.searchForVideoDateRange(camera: camera) { camera, ok, error in
            DispatchQueue.main.async{
                if ok{
                    onBoardView.setStatus(status: "")
                    let recordRange = disco.getProfile(camera: camera)
                    camera.recordingProfile = recordRange
                    onBoardView.setCamera(camera: camera, recordRange: recordRange)
                    
                }else{
                    //set status on sdcard
                    var errorStr = error
                    if error.isEmpty{
                        errorStr = "Failed to complete: " + error
                    }
                    onBoardView.setStatus(status: errorStr)
                }
            }
        }
    }
}
