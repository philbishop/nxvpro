//
//  RecordCollectionListView.swift
//  NX-V
//
//  Created by Philip Bishop on 09/01/2022.
//

import SwiftUI
import AVFoundation


class RecordCollectionModel : ObservableObject{
    @Published var collapsed = true
    var camera: Camera?
}

struct RecordCollectionView: View {
    
    
    @State var rotation: Double = 0
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()

    @ObservedObject var model = RecordCollectionModel()
    
    var recordingCollection : RecordingCollection
    var btnSize = CGFloat(14)
    var transferListener: RemoteStorageTransferListener?
    
    init(rc: RecordingCollection,camera: Camera,transferListener: RemoteStorageTransferListener? = nil){
        self.recordingCollection = rc
        self.model.camera = camera
        self.transferListener = transferListener
    }
    
    var body: some View {
        VStack{
            HStack{
                Button(action: {
                    if rotation == 0{
                        rotation = 90
                        model.collapsed = false
                    }else{
                        rotation = 0
                        model.collapsed = true
                    }
                    
                }){
                    Text(">")
                        .padding(0)
                        .font(.system(size: 12))
                        .font(.title)
                            .rotationEffect(Angle.degrees(rotation))
                }.padding(0).background(Color.clear).buttonStyle(PlainButtonStyle())
                Text(recordingCollection.label).fontWeight(.semibold).appFont(.sectionHeader)
                
                Spacer()
                
                Text(recordingCollection.countLabel).fontWeight(.semibold).frame(alignment: .trailing)
            }
            if model.collapsed == false{
                
                ForEach(recordingCollection.results) { rc in
                    HStack{
                        Text(rc.Time).appFont(.caption).padding(5)
                        Spacer()
                        if rc.Token == "FTP"{
                            //square.and.arrow.down
                            Button(action: {
                                transferListener?.doDownload(token: rc)
                            }){
                                Image(systemName: "square.and.arrow.down")
                                    .resizable()
                                    .frame(width: btnSize, height: btnSize + 2)
                                
                            }.buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                           transferListener?.doPlay(token: rc)
                        }){
                            Image(systemName: "play")
                                .resizable()
                                .frame(width: btnSize, height: btnSize)
                            
                        }.buttonStyle(PlainButtonStyle())
                            .disabled(rc.isSupportedVideoType()==false)
                        
                    }
                    
                }
            
            }
        }
    }
    
    /*
    func handleTokenTap(token: RecordToken){
        //let search = OnvifSearch()
        //search.getReplayUri(camera: model.camera!, recordToken: token)
        let imageStartTime = model.camera!.recordingProfile?.getEarliestDate()
        let diff = token.getTime()!.timeIntervalSince(imageStartTime!)
        //need to pass diff to player
        globalRecordTokenListener?.onRecordTokenSelected(camera: model.camera!, rt: token,offsetMillis: diff.milliseconds)
        
        print("Token offset",diff)
        print(token.ReplayUri)
        print("---")
    }
     */
}
            
