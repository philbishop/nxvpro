//
//  NxvProCamerasView.swift
//  nxvpro
//
//  Created by Philip Bishop on 10/02/2022.
//

import SwiftUI
var appToolbarIconSize = CGFloat(20)

class NXSearchbarModel : ObservableObject{
    @Published var searchText = "" {
        didSet{
            //print("searchText",searchText)
            //globalToolbarListener?.onFilterCameras(filter: searchText)
        }
    }
}
struct NXSearchbar : View{
    @ObservedObject var model = NXSearchbarModel()
    
    var body: some View {
        ZStack(alignment: .topTrailing){
            TextField("Filter list", text: $model.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                model.searchText = String()
            }){
                Image(systemName: "xmark.circle").resizable().opacity(0.5)
                    .frame(width:appToolbarIconSize,height: appToolbarIconSize)
            }.buttonStyle(PlainButtonStyle()).padding(.top,8)
        }//
    }
}
struct NxvProAppToolbar :  View{
    var iconSize = appToolbarIconSize
    var searchBar = NXSearchbar()
    
    var body: some View {
        HStack(spacing: 15){
            Button(action: {
              //showImportSheet = true
          }){
              Image(systemName: "plus.app")
                  .resizable()
                  //.foregroundColor(Color.accentColor)
                  .frame(width: iconSize, height: iconSize)
          }.buttonStyle(PlainButtonStyle()).padding(.leading,2)
            
            searchBar
        
            Button(action: {
                //show refresh alert
                // Button(action: {
                //show refresh alert
                //globalToolbarListener?.resetDiscovery()
                //AppDelegate.Instance.showRefreshAlert()
            }){
                Image(systemName: "arrow.triangle.2.circlepath")
                    .resizable()
                    //.foregroundColor(Color.accentColor)
                    .frame(width: iconSize + 4, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle())
            
            Button(action: {
                //show / hide multicams
                //globalToolbarListener?.toggleMulticamView()
            }){
            Image(systemName: "play")//model.isMulticamActive ? "play.slash" : "play")
                    .resizable()
                    
                    .frame(width: iconSize, height: iconSize)
                
            }.buttonStyle(PlainButtonStyle()).padding(.trailing,2)
        }.padding(.bottom)
    }
}

struct NxvProCamerasView: View {
    var body: some View {
        VStack{
            List{
                Text("No cameras found")
            }.listStyle(PlainListStyle())
            Spacer()
            NxvProAppToolbar()
        }
    }
}

struct NxvProCamerasView_Previews: PreviewProvider {
    static var previews: some View {
        NxvProCamerasView()
    }
}
