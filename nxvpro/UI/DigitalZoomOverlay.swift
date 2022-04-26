//
//  DigitalZoomOverlay.swift
//  NXV-IOS
//
//  Created by Philip Bishop on 24/04/2022.
//

import SwiftUI

struct DigiZoomCompactOverlay : View{
    
    
    var body: some View {
        
        ZStack(alignment: .topLeading){
            VStack(alignment: .leading){
                HStack{
                    HStack{
                        Image(systemName: "sidebar.left").foregroundColor(.white)
                    
                        Text(" DIGITAL ZOOM ").foregroundColor(.white).appFont(.caption)
                    }
                            .padding(5)
                            .background(Color.gray)
                            .cornerRadius(15).onTapGesture {
                                globalCameraEventListener?.toggleSideBar()
                            }
                   
                    Spacer()
                }.padding()
                
            }
            
            VStack(alignment: .trailing){
                HStack{
                    Spacer()
                    
                    Text(" RESET ").foregroundColor(.white).appFont(.caption)
                    .padding(5)
                    .background(Color.accentColor)
                    .cornerRadius(15)
                    .onTapGesture {
                        globalCameraEventListener?.resetDigitalZoom()
                    }
                        
            
                }.padding()
                
            }
            
        }
        
    }
}
