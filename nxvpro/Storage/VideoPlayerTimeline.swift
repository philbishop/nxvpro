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
    @Published var resultsByHour = [RecordingCollection]()
    
    var listener: RemoteStorageTransferListener
    
    init(token: ReplayToken,tokens: [ReplayToken],listener: RemoteStorageTransferListener){
        self.currentToken = token
        self.tokens = tokens
        self.listener = listener
        self.prepareResults()
    }
    private func prepareResults(){
        var hodLookup = [Int:RecordingCollection]()
        
        for rt in tokens{
            let dt = rt.token.getTime()
            let currentResultsDay = Calendar.current.startOfDay(for: dt!)
            let hod = Calendar.current.component(.hour, from: dt!)
            
            if hodLookup[hod] == nil{
                hodLookup[hod] = RecordingCollection(orderId: hod,label: String(hod))
            }
            hodLookup[hod]!.replayResults.append(rt)
        }
        
        var tmp = [RecordingCollection]()
        for (hr,rc) in hodLookup{
            rc.label = getLabelForHod(rc: rc)
            tmp.append(rc)
        }
        
        resultsByHour = tmp.sorted{
            return $0.orderId < $1.orderId
        }
    }
    private func getLabelForHod(rc: RecordingCollection) ->String{
        let hod = rc.orderId
        let timeRange = String(format: "%02d",hod)// + ":00 "// + String(format: "%02d",hod+1) + ":00"
        
        return timeRange// + " [" + String(rc.results.count) + "]"
    }
}

struct VideoPlayerTimeline: View {
    @ObservedObject var model: VideoPlayerTimelineModel
    
    init(token: ReplayToken,tokens: [ReplayToken],listener: RemoteStorageTransferListener){
        self.model = VideoPlayerTimelineModel(token: token,tokens: tokens,listener: listener)
        
    }
    
    var body: some View {
        HStack(spacing: 5){
            if model.resultsByHour.count == 0{
                Text(" Video stream does not contain timestamps or a duration" ).foregroundColor(.red).background(.white).padding()
            }else{
                ForEach(model.resultsByHour){ rc in
                    Menu(rc.label){
                        ForEach(rc.replayResults, id: \.self){ rt in
                            Button(rt.time,action:{
                                model.listener.doPlay(token: rt.token)
                            })
                        }
                    }
                }
            }
        }
    }
}


