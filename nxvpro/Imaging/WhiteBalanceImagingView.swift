//
//  WhiteBalanceImagingView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 04/01/2022.
//

import SwiftUI

class WhiteBalanceImagingViewModel : ObservableObject{
    @Published var name = ""
    @Published var modes = [String]()
    @Published var selectedMode = ""
    @Published var crStringValue = ""
    @Published var cbStringValue = ""
    @Published var isAuto = true
    
    @Published var labelColor = Color(UIColor.label)
    @Published var s1LabelColor = Color(UIColor.label)
    @Published var s2LabelColor = Color(UIColor.label)
    
    var sliderChanged = false
    var initialMode = ""
    
    func flagChanged(){
        if initialMode != selectedMode || sliderChanged{
            labelColor = .accentColor
        }else{
           labelColor = Color(UIColor.label)
        }
    }
    
    var opt: WhiteBalanceImagingType?
    
    func setOption(opt: WhiteBalanceImagingType){
        self.opt = opt
        self.name = opt.name.camelCaseToWords()
        self.modes.removeAll()
        
        for mode in opt.modes{
            self.modes.append(mode)
        }
        
        self.selectedMode = opt.mode
        self.isAuto = opt.mode == "AUTO"
        self.crStringValue = String(opt.crGain)
        self.cbStringValue = String(opt.cbGain)
        
        self.labelColor = Color(UIColor.label)
        self.s1LabelColor = Color(UIColor.label)
        self.s2LabelColor = Color(UIColor.label)
    }
    
    func getCrValue() -> Float{
        let pcval =  (opt!.crGain/(opt!.yrGainMax-opt!.yrGainMin)) * 100
        return Float(pcval)
    }
    func getCbValue() -> Float{
        let pcval =  (opt!.cbGain/(opt!.ybGainMax-opt!.ybGainMin)) * 100
        return Float(pcval)
    }
    
    func updateCrValue(percent: Double){
        let actual =  opt!.yrGainMin + (Double(percent) * (opt!.yrGainMax-opt!.yrGainMin))/100.0
        opt!.crGain = round(actual)
        crStringValue = String(round(actual))
        s1LabelColor = .accentColor
    }
    func updateCbValue(percent: Double){
        let actual =  opt!.ybGainMin + (Double(percent) * (opt!.ybGainMax-opt!.ybGainMin))/100.0
        opt!.cbGain = round(actual)
        cbStringValue = String(round(actual))
        s2LabelColor = .accentColor
    }
}

struct WhiteBalanceImagingView : View, NxvSliderListener, RefreshableImagingView{
    @ObservedObject var model = WhiteBalanceImagingViewModel()
    @State var crSlider = NxvSlider()
    @State var cbSlider = NxvSlider()
    
    var listener: ImagingActionListener?
    
    init(opt: WhiteBalanceImagingType,handler: ImagingItemChangeHandler,listener: ImagingActionListener?){
        self.listener = listener
        model.setOption(opt: opt)
        crSlider.model.id = 0
        cbSlider.model.id = 1
        crSlider.setPercentage(pc: model.getCrValue())
        cbSlider.setPercentage(pc: model.getCbValue())
        handler.register(optName: opt.name, imagingView: self)
    }
    
    func updateView(opt: ImagingType) {
        model.setOption(opt: opt as! WhiteBalanceImagingType)
        crSlider.model.id = 0
        cbSlider.model.id = 1
        crSlider.setPercentage(pc: model.getCrValue())
        cbSlider.setPercentage(pc: model.getCbValue())
        
    }
    
    func nxvSliderChanged(percent: Float,source: NxvSlider) {
        if source.model.id == 0{
            model.updateCrValue(percent: Double(percent))
        }else{
            model.updateCbValue(percent: Double(percent))
        }
        listener?.imagingItemChanged()
    }
    
    var body: some View {
        VStack(alignment: .leading){
            HStack{
                Text(model.name).foregroundColor(model.labelColor).appFont(.caption)
                Spacer()
            }
            Picker("", selection: $model.selectedMode) {
                ForEach(self.model.modes, id: \.self) {
                    Text($0).foregroundColor(Color(UIColor.label)).appFont(.caption)
                        
                }
            }.onChange(of: model.selectedMode) { newMode in
                model.opt!.mode = newMode
                listener?.imagingItemChanged()
                model.flagChanged()
                print("Imaging mode changed",newMode)
            }.pickerStyle(.menu)
                .frame(width: 120)
            
            if model.isAuto == false{
            
                Text("Cr gain").appFont(.caption)
                HStack{
                    crSlider
                    Text(model.crStringValue).foregroundColor(model.s1LabelColor).appFont(.smallCaption).padding(.trailing)
                }
                Text("Cb gain").appFont(.caption)
                HStack{
                    cbSlider
                    Text(model.cbStringValue).foregroundColor(model.s2LabelColor).appFont(.smallCaption).padding(.trailing)
                }
            }
        }.onAppear{
            crSlider.listener = self
            cbSlider.listener = self
        }
        
        
    }
}
