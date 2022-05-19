//
//  RecordCollectionListView.swift
//  NX-V
//
//  Created by Philip Bishop on 09/01/2022.
//

import SwiftUI
import AVFoundation

class RecordCollectionStateFactory{
    static var state = [String:Bool]()
    
    static func getCollapsedStateFor(label: String) -> Bool{
        if state[label] == nil{
            state[label] = true
        }
        return state[label]!
    }
    static func setStateFor(label: String,collapsed: Bool){
        state[label] = collapsed
    }
    
    static var seen = [String:Bool]()
    
    static func isSeen(label: String) -> Bool{
        if seen[label] == nil{
            seen[label] = false
        }
        return seen[label]!
    }
    static func setSeen(label: String){
        seen[label] = true
    }
    
    //MARK: reset when camera changes
    static func reset(){
        state.removeAll()
        seen.removeAll()
    }
}

class RecordCollectionModel : ObservableObject{
    @Published var collapsed = true
    @Published var rotation: Double = 0
    var camera: Camera?
    
    func restoreState(label: String){
        collapsed = RecordCollectionStateFactory.getCollapsedStateFor(label: label)
        rotation = collapsed ? 0 : 90
    }
}

struct RecordCollectionView: View {
    
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
        self.model.restoreState(label: rc.label)
    }
    
    var body: some View {
        VStack{
            HStack{
                Button(action: {
                    if model.rotation == 0{
                        model.rotation = 90
                        model.collapsed = false
                    }else{
                        model.rotation = 0
                        model.collapsed = true
                    }
                    self.recordingCollection.isCollasped = model.collapsed
                    RecordCollectionStateFactory.setStateFor(label: self.recordingCollection.label, collapsed: model.collapsed)
                }){
                    /*
                    Image(systemName: "greaterthan").resizable().frame(width: 11,height: 11)
                        .foregroundColor(.accentColor)
                        .padding(0)
                        .rotationEffect(Angle.degrees(model.rotation))
                     */
                    Image(systemName: (model.rotation==0 ? "arrow.right.circle" : "arrow.down.circle")).resizable().frame(width: 18,height: 18)
                }.padding(0).background(Color.clear).buttonStyle(PlainButtonStyle())
                Text(recordingCollection.label).fontWeight(.semibold).appFont(.sectionHeader)
                
                Spacer()
                
                Text(recordingCollection.countLabel).fontWeight(.semibold).frame(alignment: .trailing)
            }
            if model.collapsed == false{
                
                ForEach(recordingCollection.results) { rc in
                    
                    HStack{
                       
                        Text(rc.getTimeString()).appFont(.caption)
                            .foregroundColor(RecordCollectionStateFactory.isSeen(label: rc.Time) ? Color(UIColor.secondaryLabel) : Color(UIColor.label))
                            .padding(5)
                                             
                        Spacer()
                        if rc.hasReplayUri(){
                            //square.and.arrow.down
                            Button(action: {
                                //RecordCollectionStateFactory.setSeen(label: rc.Time)
                                transferListener?.doDownload(token: rc)
                            }){
                                Image(systemName: "square.and.arrow.down")
                                    .resizable()
                                    .frame(width: btnSize, height: btnSize + 2)
                                
                            }.buttonStyle(PlainButtonStyle())
                        }
                        
                        Button(action: {
                            RecordCollectionStateFactory.setSeen(label: rc.Time)
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
        }.onAppear{
            if self.recordingCollection.isCollasped{
                model.rotation = 0
                model.collapsed = true
            }else{
                model.rotation = 90
                model.collapsed = false
            }
        }
    }
    
}
            
