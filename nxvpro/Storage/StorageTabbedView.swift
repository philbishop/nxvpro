//
//  StorageTabbedView.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI



struct StorageTabHeaderView : View{
    
    @ObservedObject var model = TabbedViewHeaderModel()
    
    @State var onDeviceTab = NXTabItem(name: "Device",selected: true)
    @State var onBoardTab = NXTabItem(name: "Onboard",selected: false)
    @State var remoteTab = NXTabItem(name: "Remote",selected: false)
    
    
    
    func setListener(listener: NXTabSelectedListener){
        model.listener = listener
    }
    private func tabSelected(tabIndex: Int){
        onDeviceTab.model.setSelected(selected: tabIndex==0)
        onBoardTab.model.setSelected(selected: tabIndex==1)
        remoteTab.model.setSelected(selected: tabIndex==2)
        
        if let callback = model.listener{
            if tabIndex == 0{
                callback.tabSelected(tabIndex: 0, source: onDeviceTab)
            }else if tabIndex == 1{
                callback.tabSelected(tabIndex: 1, source: onBoardTab)
            }else if tabIndex == 2{
                callback.tabSelected(tabIndex: 2, source: remoteTab)
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
    let remoteView = FtpStorageView()
    
    //MARK: NXTabSelectedListener
    func tabSelected(tabIndex: Int, source: NXTabItem) {
        model.selectedTab = tabIndex
    }
    
    func setCamera(camera: Camera){
        onDeviceView.setCamera(camera: camera)
        remoteView.setCamera(camera: camera)
    }
    var body: some View {
        VStack{
            tabHeader
            ZStack(alignment: .topLeading){
                
                onDeviceView.hidden(model.selectedTab != 0)
               
                Text("Onboard storage view NOT IMPLEMENTED YET").hidden(model.selectedTab != 1)
                
                remoteView.hidden(model.selectedTab != 2)
            }
            
        }.onAppear {
            tabHeader.setListener(listener: self)
        }
    }
}
