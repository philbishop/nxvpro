//
//  ExposureImagingView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 04/01/2022.
//

import SwiftUI

class ExposureImagingViewModel : ObservableObject{
    @Published var name = ""
    @Published var modes = [String]()
    @Published var selectedMode = ""
   
    @Published var labelColor = Color(UIColor.label)
    
    var initialMode = ""
    
    func flagChanged(){
        if initialMode != selectedMode{
            labelColor = .accentColor
        }else{
           labelColor = Color(UIColor.label)
        }
    }
    /*
    @Published var minExpStringValue = ""
    @Published var maxExpStringValue = ""
    @Published var minGainStringValue = ""
    @Published var maxGainStringValue = ""
    
    
    @Published var minExSliderEnabled = true
    @Published var maxExSliderEnabled = true
    @Published var minGainSliderEnabled = true
    @Published var maxGainSliderEnabled = true
    @Published var showSliders = true
    */
    
    @Published var expStringValue = ""
    @Published var gainStringValue = ""
    @Published var irisStringValue = ""
    
    @Published var gainSliderEnabled = true
    @Published var exposureliderEnabled = true
    @Published var irisSliderEnabled = true
    @Published var showExposureSlider = false
    @Published var showGainSlider = false
    @Published var showIrisSlider = false
    
    var opt: ExposureImagingType?
    
    func setOption(opt: ExposureImagingType){
        self.opt = opt
        self.name = opt.name.camelCaseToWords()
        for mode in opt.modes{
            self.modes.append(mode)
        }
        self.selectedMode = opt.mode
        self.initialMode = opt.mode
        self.labelColor = Color(UIColor.label)
        
        //self.showSliders = opt.mode == "MANUAL"
        /*
        self.minExpStringValue = String(opt.minExposureTime)
        self.maxExpStringValue = String(opt.maxExposureTime)
        self.minGainStringValue = String(opt.minGain)
        self.maxGainStringValue = String(opt.maxGain)
        
        if opt.minGainMin == opt.minGainMax{
            minGainSliderEnabled = false
        }
        if opt.maxGainMin == opt.maxGainMax{
            maxGainSliderEnabled = false
        }
         */
        
        opt.calcExposureAndIrisForUi()
        
        self.expStringValue = String(opt.exposureTime)
        self.gainStringValue = String(opt.gain)
        self.irisStringValue = String(opt.iris)
        
        self.showExposureSlider = opt.supportsExposure()
        self.showGainSlider = opt.supportsGain()
        self.showIrisSlider = opt.supportsIris()
    }
    
    func getPercentValue(val: Double, min: Double,max: Double) -> Float{
        let pcval =  (val/(max-min)) * 100
        return Float(pcval)
    }
    /*
    func getMinExposurePercent() -> Float{
        return getPercentValue(val: opt!.minExposureTime, min: opt!.minExposureTimeMin, max: opt!.minExposureTimeMax)
    }
    func getMaxExposurePercent() -> Float{
        return getPercentValue(val: opt!.maxExposureTime, min: opt!.maxExposureTimeMin, max: opt!.maxExposureTimeMax)
    }
    func getMinGainPercent() -> Float{
        return getPercentValue(val: opt!.minGain, min: opt!.minGainMin, max: opt!.minGainMax)
    }
    func getMaxGainPercent() -> Float{
        return getPercentValue(val: opt!.maxGain, min: opt!.maxGainMin, max: opt!.maxGainMax)
    }
    */
    func getExposurePercent() -> Float{
           return getPercentValue(val: opt!.exposureTime, min: opt!.minExposureTime, max: opt!.maxExposureTime)
       }
    func getGainPercent() -> Float{
           return getPercentValue(val: opt!.gain, min: opt!.minGain, max: opt!.maxGain)
       }
    
    func getIrisPercent() -> Float{
        if let iop = opt{
            var min = iop.minIris
            var max = iop.maxIris
            if min < 0{
                let offset = min * -1
                min = 0
                max += offset
                let val = iop.iris + offset
                let factor = 1.0
                let pc = getPercentValue(val: val * factor, min: min * factor, max: max * factor)
                return pc
            }
        }
           return getPercentValue(val: opt!.iris, min: opt!.minIris, max: opt!.maxIris)
       }
    func updateExposure(pc: Float){
        let actual =  opt!.minExposureTime + (Double(pc) * (opt!.maxExposureTime-opt!.minExposureTime))/100.0
        //newMinExValue = actual
        opt!.exposureTime = roundTo2Dp(actual)
        expStringValue = String(opt!.exposureTime)
    }
    func updateGain(pc: Float){
        let actual =  opt!.minGain + (Double(pc) * (opt!.maxGain-opt!.minGain))/100.0
        //newMinExValue = actual
        opt!.gain = roundTo2Dp(actual)
        gainStringValue = String(opt!.gain)
    }
    func updateIris(pc: Float){
        var actual =  opt!.minIris + (Double(pc) * (opt!.maxIris-opt!.minIris))/100.0
        //AppLog.write("updateIris",pc,opt!.iris,opt!.minIris,opt!.maxIris,roundTo2Dp(actual))
       
        opt!.iris = roundTo2Dp(actual)
        irisStringValue = String(opt!.iris)
        flagChanged()
    }
    /*
    func updateMinExposure(pc: Float){
        let actual =  opt!.minExposureTimeMin + (Double(pc) * (opt!.minExposureTimeMax-opt!.minExposureTimeMin))/100.0
        //newMinExValue = actual
        opt!.minExposureTime = roundTo2Dp(actual)
        minExpStringValue = String(opt!.minExposureTime)
    }
    func updateMaxExposure(pc: Float){
        let actual =  opt!.maxExposureTimeMin + (Double(pc) * (opt!.maxExposureTimeMax-opt!.maxExposureTimeMin))/100.0
        //newMaxExValue = actual
        opt!.maxExposureTime = roundTo2Dp(actual)
        maxExpStringValue = String(opt!.maxExposureTime)
    }
    func updateMinGain(pc: Float){
        let actual =  opt!.minGainMin + (Double(pc) * (opt!.minGainMax-opt!.minGainMin))/100.0
        //newMinGainValue = round(actual)
        opt!.minGain = roundTo2Dp(actual)
        minGainStringValue = String(opt!.minGain)
    }
    func updateMaxGain(pc: Float){
        let actual =  opt!.maxGainMin + (Double(pc) * (opt!.maxGainMax-opt!.maxGainMin))/100.0
        //newMaxGainValue = actual
        opt!.maxGain = roundTo2Dp(actual)
        maxGainStringValue = String(opt!.maxGain)
    }
     */
    private func roundTo2Dp(_ val: Double) -> Double{
        return round(val * 100) / 100
    }
}

struct ExposureImagingView : View, NxvSliderListener, RefreshableImagingView{
 
    @ObservedObject var model = ExposureImagingViewModel()
    
    
    
    /*
    @State var minExposureSlider = NxvSlider(minVal: 0)
    @State var maxExposureSlider = NxvSlider(minVal: 0)
    @State var minGainSlider = NxvSlider(minVal: 0)
    @State var maxGainSlider = NxvSlider(minVal: 0)
    */
    @State var exposureSlider = NxvSlider(minVal: 0)
    @State var gainSlider = NxvSlider(minVal: 0)
    @State var irisSlider = NxvSlider(minVal: 0)
    
    var listener: ImagingActionListener?
    
    init(opt: ExposureImagingType,handler: ImagingItemChangeHandler,listener: ImagingActionListener?){
        self.listener = listener
        model.setOption(opt: opt)
        
        
        handler.register(optName: opt.name,imagingView: self)
    }
    func initOpt(){
       
        exposureSlider.model.id = 0
        gainSlider.model.id = 1
        irisSlider.model.id = 2
        
        //exposureSlider.model.minValue = model.opt?.minExposureTime
        
        exposureSlider.setPercentage(pc: model.getExposurePercent())
        gainSlider.setPercentage(pc: model.getGainPercent())
        irisSlider.setPercentage(pc: model.getIrisPercent())
    
        
        /*
        minExposureSlider.model.id = 0
        maxExposureSlider.model.id = 1
        minGainSlider.model.id = 2
        maxGainSlider.model.id = 3
        
        minGainSlider.model.minValue = 0
        maxGainSlider.model.minValue = 0
        minExposureSlider.model.minValue = 0
        maxExposureSlider.model.minValue = 0
        
        minExposureSlider.setPercentage(pc: model.getMinExposurePercent())
        maxGainSlider.setPercentage(pc: model.getMaxExposurePercent())
        minGainSlider.setPercentage(pc: model.getMinGainPercent())
        maxGainSlider.setPercentage(pc: model.getMaxGainPercent())
    */
    }
    func updateView(opt: ImagingType) {
        AppLog.write("updateView",opt.xmlName)
        let newOpt = opt as! ExposureImagingType
        model.opt = newOpt
        initOpt()
    }
    func nxvSliderChanged(percent: Float,source: NxvSlider) {
        switch(source.model.id){
        case 0:
            model.updateExposure(pc: percent)
            break
        case 1:
            model.updateGain(pc: percent)
            break
        case 2:
            model.updateIris(pc: percent)
            break
        default:
            break
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
                AppLog.write("Imaging mode changed",newMode)
            }.pickerStyle(.menu)
            .disabled(model.modes.count < 2)
            .frame(width: 120)
            
            if model.showExposureSlider{
                Text("Exposure time")
                HStack{
                    exposureSlider
                    Text(model.expStringValue).appFont(.smallCaption).padding(.trailing)
                }
            //}
            //if model.showGainSlider{
                Text("Gain")
                HStack{
                    gainSlider
                    Text(model.gainStringValue).appFont(.smallCaption).padding(.trailing)
                }
            }
            if model.showIrisSlider{
                Text("Iris")
                HStack{
                    irisSlider
                    Text(model.irisStringValue).appFont(.smallCaption).padding(.trailing)
                }
            }
            /*
            if model.showSliders{
               
                Text("Min Exposure time")
                HStack{
                    minExposureSlider
                    Text(model.minExpStringValue).appFont(.smallCaption).padding(.trailing)
                }
                Text("Max Exposure time")
                HStack{
                    maxExposureSlider
                    Text(model.maxExpStringValue).appFont(.smallCaption).padding(.trailing)
                }
                Text("Min gain")
                HStack{
                    minGainSlider.disabled(model.minGainSliderEnabled==false).opacity(model.minGainSliderEnabled ? 1.0 : 0.3)
                    Text(model.minGainStringValue).appFont(.smallCaption).padding(.trailing)
                }
                Text("Max gain")
                HStack{
                    maxGainSlider.disabled(model.maxGainSliderEnabled==false).opacity(model.maxGainSliderEnabled ? 1.0 : 0.3)
                    Text(model.maxGainStringValue).appFont(.smallCaption).padding(.trailing)
                }
             }
            */
            
        }.onAppear{
            initOpt()
            /*
            minGainSlider.listener = self
            maxGainSlider.listener = self
            maxExposureSlider.listener = self
            minExposureSlider.listener = self
            */
            exposureSlider.listener = self
            gainSlider.listener = self
            irisSlider.listener = self
        }
    }
}


