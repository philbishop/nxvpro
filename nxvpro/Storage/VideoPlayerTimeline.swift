//
//  VideoPlayerTimeline.swift
//  nxvpro
//
//  Created by Philip Bishop on 27/02/2022.
//

import SwiftUI

class ReplayToken : Hashable{
    var id: Int
    var token: RecordToken
    var time: String
    init(id: Int,token: RecordToken){
        self.id = id
        self.token = token
        self.time = token.getTimeOfDayString()
        
    }
    
    static func == (lhs: ReplayToken, rhs: ReplayToken) -> Bool {
        return lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
class VideoPlayerTimelineModel : ObservableObject{
    @Published var tokens: [ReplayToken]
    @Published var currentToken: ReplayToken
    
    var listener: RemoteStorageTransferListener
    
    init(token: ReplayToken,tokens: [ReplayToken],listener: RemoteStorageTransferListener){
        self.currentToken = token
        self.tokens = tokens
        self.listener = listener
       
    }
    
}

struct VideoPlayerTimeline: View {
    @ObservedObject var model: VideoPlayerTimelineModel
    
    
    
    init(token: ReplayToken,tokens: [ReplayToken],listener: RemoteStorageTransferListener){
        self.model = VideoPlayerTimelineModel(token: token,tokens: tokens,listener: listener)
        
    }
    
    var body: some View {
        //HStack{
            Picker("Date",selection: $model.currentToken){
                ForEach(model.tokens, id: \.self) { token in
                    Text(token.time)
                   
                }
            }.onChange(of: model.currentToken) { newValue in
                print("VideoTimelineChanged",newValue.time,model.currentToken.time)
                //model.currentToken = newValue
                model.listener.doPlay(token: newValue.token)
                    
              
            }
        
    }
}


