//
//  FtpStorageView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 27/01/2022.
//

import SwiftUI
import Network


class FtpStorageViewModel : ObservableObject, FtpDataSourceListener{
        
    var ftpSource: FtpDataSource?
    var searchDate: Date?
    var results = [RecordToken]()
    @Published var resultsByHour = [RecordingCollection]()
    
    var barchartModel: SDCardBarChartModel?
    var statsView: SDCardStatsView?
    var remoteSearchListenr: RemoteSearchCompletionListener?
    var ftpPath = "/"
    var fileExt = ".mp4"
    var host = ""
    var cred: URLCredential?
    
    @Published var storageHelp = ""
    
    init(){
        setTextForResource(res: "remote_storage")
    }
    func setTextForResource(res: String){
        if let filepath = Bundle.main.path(forResource: res, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                //print(contents)
                storageHelp = contents
                
            } catch {
                print("storageHelp help: \(error)")
            }
        }else{
            print("storageHelp help: Can't find",res)
        }
    }
    
    private func getTimeString(date: Date) -> String{
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yyyy HH:mm:ss"
        return fmt.string(from: date)
    }
    private func getDay() -> String{
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yyyy"
        return fmt.string(from: searchDate!)
    }
    
    var camera: Camera?

    func doSmbSearch(camera: Camera,date: Date,scheme: String){
        
        if searchDate != nil && Calendar.current.isDate(searchDate!, inSameDayAs: date) == false{
            results.removeAll()
            //resultsByHour.removeAll()
            populateFromCache(camera: camera, date: date,storageType: .smb)
        }
        remoteSearchListenr?.onRemoteSearchComplete(success: false, status: "SBM not supported")
        /*
        //update the callers status because populate from cache will force a refresh
        remoteSearchListenr?.onRemoteSearchComplete(success: true, status: "Searching....")
        
        self.camera = camera
        self.searchDate = date
        statsView?.setCamera(camera: camera,storageType: .smb)
        
        let mountName = camera.storageSettings.path.replacingOccurrences(of: "/", with: "")
        
        let localDir = FileHelper.getMountStorageRoot()
        let localMountDir = localDir.appendingPathComponent(mountName)
        let fileExt = camera.storageSettings.fileExt
        
        let smb = SMBDataSource(scheme: scheme)
        
        results = smb.getFiles(localMountDir, fileExt: fileExt,date: searchDate!)
        
        DispatchQueue.main.async {
            self.remoteSearchListenr?.onRemoteSearchComplete(success: true,status: "Search complete")
            self.done()
        }
         */
    }
    func doSearch(camera: Camera,date: Date,host: String,path: String,fileExt: String,credential: URLCredential){
        
        if searchDate != nil && Calendar.current.isDate(searchDate!, inSameDayAs: date) == false{
            results.removeAll()
            //resultsByHour.removeAll()
            populateFromCache(camera: camera, date: date,storageType: .ftp)
        }
        //update the callers status because populate from cache will force a refresh
        remoteSearchListenr?.onRemoteSearchComplete(success: true, status: "Searching....")
        
        self.camera = camera
        self.host = host
        self.cred = credential
        statsView?.setCamera(camera: camera,storageType: .ftp)
        searchDate = date
        ftpPath = path
        self.fileExt = fileExt
        ftpSource = FtpDataSource(listener: self)
        if ftpSource!.connect(credential: credential, host: host){
            ftpSource!.searchPath(path: path)
        }else{
            actionComplete(success: false)
        }
        
    }
    
    func actionComplete(success: Bool){
        print("FtpStorageViewModel:actionComplete",success)
        if !success{
            remoteSearchListenr?.onRemoteSearchComplete(success: false, status: "Failed to complete")
        }
    }
    var validExts = ["mp4","avi","dav"]
    
    func fileFound(path: String,modified: Date?){
        if let fd = modified{
           let sd = searchDate!
            if Calendar.current.isDate(fd, inSameDayAs: sd){
                print("FtpStorageViewModel:fileFound matched day",path,modified)
                let fparts = path.components(separatedBy: ".")
                if fparts.count == 0{
                    return
                }
                let ext = fparts[fparts.count-1]
                
                if self.validExts.contains(ext){
                    
                    print(">>>FtpStorageViewModel:fileFound matched day and ext",path,modified)
                    
                    
                    let rt = RecordToken()
                    rt.storageType = .ftp
                    rt.fileDate = fd
                    rt.Time = getTimeString(date: fd)
                    rt.ReplayUri = path
                    rt.day = sd
                    rt.Token = "FTP"
                    rt.remoteHost = host
                    rt.creds = cred
                    //check for duplicates
                    if addIfNotInResults(rt: rt){
                        refreshResults()
                    }
                }
            }
            
        }
        
    }
    
    private func addIfNotInResults(rt: RecordToken) -> Bool{
        
        for r in results{
            if r.ReplayUri == rt.ReplayUri{
                return false
            }
        }
        
        results.append(rt)
        return true
    }
    
    func done(){
        //save results
        saveResults()
        refreshResults()
        statsView?.refreshStats()
        
    }
    
    var downloadToken: RecordToken?
    func downloadFile(token: RecordToken){
        downloadToken = token
        
        if token.storageType != .ftp{
            let furl = URL(fileURLWithPath: token.ReplayUri)
            let fparts = token.ReplayUri.components(separatedBy: "/")
            let fname = fparts[fparts.count-1]
            
           
            let targetUrl = FileHelper.getDownloadsDir().appendingPathComponent(fname)
            do{
                try FileManager.default.copyItem(at: furl, to: targetUrl)
                    downloadComplete(localFilePath: targetUrl.path, success: nil)
            }catch{
                let msg = "\(error.localizedDescription)"
                downloadComplete(localFilePath: targetUrl.path, success: msg)
            }
                        
        }else{
        
            let ftpDataSrc = FtpDataSource(listener: self)
            let ok = ftpDataSrc.connect(credential: token.creds!, host: token.remoteHost)
            if ok{
                ftpDataSrc.download(path: token.ReplayUri)
            }
        }
    }
    func downloadComplete(localFilePath: String,success: String?) {
        print("FtpStorageViewModeldownloadComplete",success)
        var msg = "Download completed OK"
        
        if success != nil{
            msg = "Download " + success!
        }else{
            downloadToken!.localFilePath = localFilePath
            let fparts = localFilePath.components(separatedBy: "/")
            let dlPath = "Downloads/" + fparts[fparts.count-1]
            
            msg = msg + "\n" + dlPath
        }
        DispatchQueue.main.async{
            //AppDelegate.Instance.showMessageAlert(title: "File transfer info",message: msg)
        }
    }
    
    //MARK: Results UI
    func refreshResults(){
        var hodLookup = [Int:RecordingCollection]()
        for rt in results{
            
            let dt = rt.fileDate
            let hod = Calendar.current.component(.hour, from: dt!)
            
            if hodLookup[hod] == nil{
                hodLookup[hod] = RecordingCollection(orderId: hod,label: String(hod))
            }
            hodLookup[hod]!.results.append(rt)
            
            
        }
        var tmp = [RecordingCollection]()
        for (hr,rc) in hodLookup{
            rc.label = getLabelForHod(rc: rc)
            tmp.append(rc)
        }
        DispatchQueue.main.async {
            
            self.resultsByHour = tmp.sorted{
                return $0.orderId < $1.orderId
            }
            
            self.calculatBarchartStats()
            self.remoteSearchListenr?.onRemoteSearchComplete(success: true, status: "Found " + String(self.results.count) + " items")
        }
        
        
        
    }
    func directoryFound(dir: String){
        print("FtpStorageViewModel:directoryFound",dir)
    }
    private func getLabelForHod(rc: RecordingCollection) ->String{
        let hod = rc.orderId
        let timeRange = String(format: "%02d",hod) + ":00 - " + String(format: "%02d",hod+1) + ":00"
        
        return timeRange// + " [" + String(rc.results.count) + "]"
    }
    private func calculatBarchartStats(){
        var counts = [Int]()
        for i in 0...24{
            counts.append(0)
        }
        for results in resultsByHour{
            for rt in results.results{
                let dt = rt.fileDate
                let hod = Calendar.current.component(.hour, from: dt!)
                
                counts[hod] = counts[hod] + 1
            }
        }
        
        var maxCount = 0.0
        for count in counts{
            maxCount = max(maxCount,Double(count))
        }
        
        var barLevels = [Double]()
        
        for i in 0...barchartModel!.bars.count-1{
            let relVal = (Double(counts[i]) / maxCount )
            let barHeight = 24.0 * relVal
            barLevels.append(barHeight.isNaN ? 0.0 : barHeight)
        }
        
        barchartModel!.setBarLevels(levels: barLevels)
        
        
    }
    
    //MARK: Caching results
  
    func populateFromCache(camera: Camera,date: Date,storageType: StorageType){
        self.camera = camera
        self.searchDate = date
        results.removeAll()
        resultsByHour.removeAll()
        
        let cachedPath = StorageHelper.getRemoteCacheFilePath(camera: camera, searchDate: date, storageType: storageType)
        if FileManager.default.fileExists(atPath: cachedPath.path){
            do{
                let csvData = try Data(contentsOf: cachedPath)
                let allLines = String(data: csvData, encoding: .utf8)!
                let lines = allLines.components(separatedBy: "\n")
                for line in lines{
                    if line.isEmpty{
                        continue
                    }
                    let rt = RecordToken()
                    rt.fromFtpCsv(line: line)
                    
                
                    
                    results.append(rt)
                }
            }catch{
                print("error reading FTP CSV")
            }
        }
       
        refreshResults()
        statsView?.refreshStats()
    }
    
    /*
    private func getCacheFilePath() -> URL{
        let startOfOay = Calendar.current.startOfDay(for: searchDate!)
        
        let sdCardRoot = FileHelper.getSdCardStorageRoot()
        var frmt = DateFormatter()
        frmt.dateFormat="yyyyMMdd"
        let dayStr =  frmt.string(from: startOfOay)
        let camUid = camera!.isVirtual ? camera!.getBaseFileName() : camera!.getStringUid()
        let filename = camUid + "_ftp_" +  dayStr + ".csv"
        let saveToPath = sdCardRoot.appendingPathComponent(filename)
        return saveToPath
    }
    */
    
    private func saveResults(appendToCache: Bool  = false){
        var buf = ""
        for rt in results{
            buf.append(rt.toFtpCsv())
            buf.append("\n")
        }
        let saveToPath = StorageHelper.getRemoteCacheFilePath(camera: camera!, searchDate: searchDate!, storageType: .ftp)
        
        do{
            var writeToFile = true
            if appendToCache{
                
               
                
                if let fileUpdater = try? FileHandle(forUpdating: saveToPath) {

                    // Function which when called will cause all updates to start from end of the file
                    fileUpdater.seekToEndOfFile()
                    // Which lets the caller move editing to any position within the file by supplying an offset
                    fileUpdater.write(buf.data(using: .utf8)!)

                    // Once we convert our new content to data and write it, we close the file and that’s it!
                    fileUpdater.closeFile()
                    
                    writeToFile = false
                }
            }
            if writeToFile{
                try buf.write(toFile: saveToPath.path, atomically: true, encoding: String.Encoding.utf8)
            }
            print(saveToPath.path)
        }catch{
            print("Failed to save recording events CSV",saveToPath)
        }
    }
    
}

struct FtpStorageView: View, RemoteStorageActionListener, RemoteStorageTransferListener {
    
    @ObservedObject var model = FtpStorageViewModel()
    var rangeView = RemoteStorageConfigView()
  
    var statsView = SDCardStatsView()
    var searchView = RemoteStorageSearchView()
    var rightPaneWidth = CGFloat(410.0)
    var barChart = SDCardBarChart()
    
    func setCamera(camera: Camera){
        //load ftp settings
        model.barchartModel = barChart.model
        //load settings
        camera.loadStorageSettings(storageType: "ftp")
        model.statsView = statsView
        searchView.setCamera(camera: camera, listener: self)
        
        model.remoteSearchListenr = searchView.model
        
        statsView.setCamera(camera: camera, storageType: .ftp)
        
        var storageType = StorageType.ftp
        if camera.storageSettings.storageType == "smb"{
            storageType = StorageType.smb
        }
        
        model.populateFromCache(camera: camera, date: Date(),storageType: storageType)
        
#if DEBUG_SMB
        if camera.getDisplayName().contains("IPC-B140"){
            camera.storageSettings.user = "nxv_ftp"
            camera.storageSettings.password = "Inc@X2022Nxv"
            camera.storageSettings.host="192.168.137.199"//"216.250.119.22"
            camera.storageSettings.path = "/HKSMB"
            camera.storageSettings.fileExt = ".mp4"
            camera.storageSettings.authenticated = true
            camera.storageSettings.storageType = "SMB"
            camera.storageSettings.port = "556"
        }
#endif
#if DEBUG_TEST
        if camera.getDisplayName().contains("Amcrest"){
            camera.storageSettings.user = "Camera"//"nxv_ftp"
            camera.storageSettings.password = "Inc@X2022Nxv"
            camera.storageSettings.host="192.168.137.1"//"216.250.119.22"
            //camera.storageSettings.path = "/Amcrest_1"
            camera.storageSettings.fileExt = ".mp4"
        }else if camera.xAddr.contains(":8082"){
            //IP Realtime
            camera.storageSettings.user = "nxv_ftp"
            camera.storageSettings.password = "Inc@X2022Nxv"
            camera.storageSettings.host="216.250.119.22"//"216.250.119.22"
            camera.storageSettings.path = "/ZEN2sDM4_C00028"
            camera.storageSettings.fileExt = ".dav"
            camera.storageSettings.authenticated = true
        }else if camera.xAddr.contains(":8085"){
            //IP Realtime
            camera.storageSettings.user = "nxv_ftp"
            camera.storageSettings.password = "Inc@X2022Nxv"
            camera.storageSettings.host="216.250.119.22"//"216.250.119.22"
            camera.storageSettings.path = "/Starlight"
            camera.storageSettings.fileExt = ".avi"
            camera.storageSettings.authenticated = true
        }
                    
#endif
        
        rangeView.setCamera(camera: camera,changeListener: searchView)
        
        
    }
    
    func doSearch(camera: Camera, date: Date, useCache: Bool) {
        print("FtpStorageView:doSearch",date,camera.getDisplayName())
    
        barChart.reset()
        let st = camera.storageSettings.storageType
        if st ==  "ftp"{
        
            let ftpSettings = rangeView.ftpSettingsView
            var hostAndPort = ftpSettings.getHostAndPort()
            let path = ftpSettings.model.path
            let fileExt = ftpSettings.model.fileExt
            let creds = ftpSettings.getCredentials()
            model.doSearch(camera: camera,date: date, host: hostAndPort,path: path,fileExt: fileExt ,credential: creds)
        }else{
            model.doSmbSearch(camera: camera, date: date,scheme: st)
        }
    }
    
    func doDownload(token: RecordToken) {
        
        //AppDelegate.Instance.promptToDownload(token: token, model: model)
    }
    func doPlay(token: RecordToken) {
        //AppDelegate.Instance.playRemoteVideo(camera: model.camera!, token: token)
    }
    
    
    var body: some View {
        ZStack(){
            HStack{
                VStack{
                    rangeView
                    searchView
                    List{
                        ForEach(model.resultsByHour){ rc in
                            RecordCollectionView(rc: rc,camera: searchView.model.camera!,transferListener: self)
                        }
                    }
                    Spacer()
                    HStack{
                        barChart.frame(height: 24,alignment: .center)
                    }.padding()
                }
                VStack{
                    if searchView.model.searchDisabled{
                        Text("Setup").appFont(.smallTitle).padding()
                        Text(model.storageHelp).appFont(.sectionHeader).padding()
                    }else{
                        Text("Statistics").appFont(.smallTitle)
                        statsView
                    }
                    Spacer()
                    //Text("Settings").appFont(.sectionHeader)
                    //ftpSettings
                    
                }
                .frame(width: rightPaneWidth)
            }
            
        }
    }
}



struct FtpStorageView_Previews: PreviewProvider {
    static var previews: some View {
        FtpStorageView()
    }
}
