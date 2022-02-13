//
//  FocusImagingView.swift
//  NX-V
//
//  Created by Philip Bishop on 18/01/2022.
//

import SwiftUI

class FocusImagingViewModel : ObservableObject {
    @Published var name = "Focus settings"
    @Published var val = ""
    
    var opt: FocusImagingType?
    
    func setOption(opt: FocusImagingType){
        self.opt = opt
    }
}
struct FocusImagingView : View, RefreshableImagingView{
    
    @ObservedObject var model = FocusImagingViewModel()
    
    init(opt: FocusImagingType,handler: ImagingItemChangeHandler){
        model.setOption(opt: opt)
        handler.register(optName: opt.name, imagingView: self)
    }
    
    func updateView(opt: ImagingType) {
        model.setOption(opt: opt as! FocusImagingType)
    }
    
    var body: some View {
        VStack(alignment: .leading){
            Divider()
            HStack{
                Text(model.name).appFont(.caption)
                Spacer()
            }
            HStack{
                Text("Read only").fontWeight(.light).appFont(.caption).padding(5)
                Spacer()
            }
            Divider()
        }
    }
}
