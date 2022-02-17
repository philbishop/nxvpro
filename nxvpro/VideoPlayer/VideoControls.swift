//
//  VideoPlayerControls.swift
//  DesignIdeas
//
//  Created by Philip Bishop on 06/06/2021.
//

import SwiftUI

class VideoComtrolsModel : ObservableObject{
    @Published var elaspsedTime: String = "00:00"
    @Published var remainingTime: String = "--:--"
    @Published var position: Double = 0.0
    @Published var volumeOn: Bool = true
    var duration: Double = 0.0
    var globalVideoPlayer: VlcPlayerNSView?
}

struct VideoPlayerControls: View, NxvSliderListener {
    
    
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var iconModel = AppIconModel()
    @ObservedObject var model = VideoComtrolsModel()
    @State var position: Double = 0.0
    @State var duration: Double = 100.0
    
    @State var slider = NxvSlider()
    
    func nxvSliderChanged(percent: Float,source: NxvSlider) {
        let posRel = Double(percent) / Double(100)
        let vidPos = model.duration * posRel
        model.globalVideoPlayer?.moveTo(position: vidPos)
        if model.globalVideoPlayer?.isPlaying() == false {
            model.globalVideoPlayer?.mediaPlayer?.play()
        }
    }
    
    func setPlayer(player: VlcPlayerNSView){
        model.globalVideoPlayer = player
    }
    
    
    var body: some View {
        let videoPlayerView = model.globalVideoPlayer
        
        ZStack(alignment: .top){
            GeometryReader { fullView in
                let isSmallScreen = fullView.size.width < 350
                let srubberWidth = fullView.size.width - ( isSmallScreen ? 170 : 210)
                HStack{
                    
                    Button(action: {
                        if videoPlayerView!.isPlaying() {
                            videoPlayerView!.pause()
                        }else{
                            videoPlayerView!.resume()
                        }
                    }){
                        Image(iconModel.activePlayIcon).resizable().frame(width: 24,height: 24)
                    }
                    
                    
                    
                    /*
                    Slider(value: $model.position, in: 0...100,onEditingChanged: { data in
                        self.changeVideoPosition()
                    }).frame(width: srubberWidth)
                    */
                    
                    slider.frame(width: srubberWidth,height: 22)
                    
                    Text(model.elaspsedTime).appFont(.footnote)//.foregroundColor(Color.accentColor)
                    if !isSmallScreen{
                        Text(model.remainingTime).appFont(.footnote).opacity(0.7)
                    }
                    //MUTE
                    Button(action: {
                        model.volumeOn = !model.volumeOn
                        iconModel.volumeStatusChange(on: model.volumeOn)
                        videoPlayerView?.mediaPlayer!.audio.volume = model.volumeOn ? 100 : 0
                    }){
                        Image(iconModel.activeVolumeIcon).resizable().frame(width: 32,height: 32)
                    }
                    
                    //ROTATE
                    Button(action: {
                        videoPlayerView?.rotateNext()
                    }){
                        //Text("􀎰")
                        Image(iconModel.rotateIcon).resizable().frame(width: 30, height: 30)
                    }
 
                }
            }.padding(4).frame(height: 38).background(Color(UIColor.systemGroupedBackground)).cornerRadius(25)
        }.padding().onAppear(){
            iconModel.initIcons(isDark: colorScheme == .dark)
            slider.listener = self
        }
    }
    
    func playerStarted(playing: Bool){
        iconModel.playStatusChange(playing: playing)
    }
    func timeChanged(time: String,remaining: String,position: Int,duration: Int){
        model.elaspsedTime = time
        model.remainingTime = remaining
        model.duration = Double(duration)
        let relPos = (Double(position) / Double(duration)) * 100.0
       
        model.position = relPos
        
        slider.setPercentage(pc: Float(relPos))
        if model.position == model.duration{
            iconModel.playStatusChange(playing: false)
        }
       
    }
    func changeVideoPosition(){
        let posRel = Double(model.position) / Double(100)
        let vidPos = model.duration * posRel
        model.globalVideoPlayer?.moveTo(position: vidPos)
    }
}

struct VideoPlayerControls_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerControls()
    }
}
