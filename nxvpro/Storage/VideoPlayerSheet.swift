//
//  VideoPlayerSheet.swift
//  nxvpro
//
//  Created by Philip Bishop on 14/02/2022.
//

import SwiftUI

class VideoPlayerSheetModel : ObservableObject{
    var title = ""
    var listener: VideoPlayerDimissListener?
    
    func setCard(video: CardData){
        title = video.name + " " + video.shortDateString()
    }
}

struct VideoPlayerSheet : View{
    
    @ObservedObject var model = VideoPlayerSheetModel()
    let playerView = VideoPlayerView()
    
    init(video: CardData,listener: VideoPlayerDimissListener){
        model.listener = listener
        model.setCard(video: video)
        playerView.play(video: video)
    }
    
    var body: some View {
        VStack{
            HStack{
                VStack{
                    Text(model.title).appFont(.smallTitle)
                        .padding()
                }
                Spacer()
                Button(action: {
                    playerView.stop()
                    model.listener?.dimissPlayer()
                })
                {
                    Image(systemName: "xmark").resizable()
                        .frame(width: 14,height: 14).padding()
                }.foregroundColor(Color.accentColor)
            }
           
        
            playerView
        }
    }
}
