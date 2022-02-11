//
//  ContentView.swift
//  nxvpro
//
//  Created by Philip Bishop on 09/02/2022.
//

import SwiftUI
extension View {
    @ViewBuilder func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide { hidden() }
        else { self }
    }
}

class NxvProContentViewModel : ObservableObject{
    
    @Published var leftPaneWidth = CGFloat(275.0)
}
struct NXTabHeaderView: View {
    
    var tabHeight = CGFloat(32.0)
    
    @State var camTab = NXTabItem(name: "Cameras",selected: true)
    @State var grpsTab = NXTabItem(name: "Groups")
    @State var mapTab = NXTabItem(name: "Map")
    
    private func tabSelected(tabIndex: Int){
        camTab.model.setSelected(selected: tabIndex==0)
        grpsTab.model.setSelected(selected: tabIndex==1)
        mapTab.model.setSelected(selected: tabIndex==2)
    }
    
    var body: some View {
        
        HStack(spacing: 7){
           
            //tab view
           
            camTab.padding(.leading).onTapGesture {
                tabSelected(tabIndex: 0)
            }
    
            grpsTab.onTapGesture {
                tabSelected(tabIndex: 1)
            }
            
            mapTab.onTapGesture {
                tabSelected(tabIndex: 2)
            }
            
            Spacer()
        }.frame(height: tabHeight)
    }
}

struct NxvProContentView: View, DiscoveryListener {
    
    @ObservedObject var model = NxvProContentViewModel()
    
    var titlebarHeight = 32.0
    
    let disco = OnvifDisco()
    
    var body: some View {
        GeometryReader { fullView in
            let rightPaneWidth = fullView.size.width - model.leftPaneWidth
            let vheight = fullView.size.height - titlebarHeight
            VStack{
                HStack{
                    
                    Button(action:{
                        if model.leftPaneWidth == 0{
                            model.leftPaneWidth = CGFloat(275.0)
                        }else{
                            model.leftPaneWidth = 0
                        }
                    }){
                        Image(systemName: "sidebar.left")
                    }.padding(.leading)
                 Spacer()
                    Text("NX-V PRO").fontWeight(.medium)
                        .appFont(.titleBar)
                    Spacer()
                    
                }.frame(width: fullView.size.width,height: titlebarHeight)
                
                HStack(){
                    VStack(alignment: .leading,spacing: 0){
                        
                        NXTabHeaderView()
                        
                        //Selected Tab Lists go here
                        NxvProCamerasView().padding(.leading)
                        //Spacer()
                        
                    }
                    .hidden(model.leftPaneWidth == 0)
                    .frame(width: model.leftPaneWidth,height: vheight)
                    
                    ZStack{
                        Color(UIColor.secondarySystemBackground)
                        Text("Searching for cameras...")
                    }
                    Spacer()
                }
            }
        }.onAppear(){
            disco.start()
        }
    }

    //MARK: DiscoveryListener
    func cameraAdded(camera: Camera) {
        
    }
    
    func cameraChanged(camera: Camera) {
        
    }
    
    func discoveryError(error: String) {
        
    }
    
    func discoveryTimeout() {
        
    }
    
    func networkNotAvailabled(error: String) {
    
    }
    
    func zombieStateChange(camera: Camera) {
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProContentView()
.previewInterfaceOrientation(.landscapeLeft)
    }
}
