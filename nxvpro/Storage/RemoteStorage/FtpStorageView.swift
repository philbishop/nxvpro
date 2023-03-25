//
//  FtpStorageView.swift
//  TestMacUI
//
//  Created by Philip Bishop on 27/01/2022.
//

import SwiftUI
import Network
import FilesProvider

class FtpStorageViewModel : ObservableObject, FtpDataSourceListener{
        
    var ftpSource: FtpDataSource?
    var searchDate: Date?
    @Published var results = [RecordToken]()
    @Published var resultsByHour = [RecordingCollection]()
    @Published var showSetup = true
    @Published var isSearching = false
    
    var barchartModel: SDCardBarChartModel?
    var statsView: SDCardStatsView?
    var remoteSearchListenr: RemoteSearchCompletionListener?
    var videoPlayerSheet = VideoPlayerSheet()
    
    var ftpPath = "/"
    var fileExt = ".mp4"
    var host = ""
    var cred: URLCredential?
    
    @Published var storageHelp = ""
    @Published var selectedToken: RecordToken?
    
    @Published var showPlayer = false
    
    init(){
        setTextForResource(res: "remote_storage")
        ftpSource = FtpDataSource(listener: self)
    }
    func setTextForResource(res: String){
        if let filepath = Bundle.main.path(forResource: res, ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                //AppLog.write(contents)
                storageHelp = contents
                
            } catch {
                AppLog.write("storageHelp help: \(error)")
            }
        }else{
            AppLog.write("storageHelp help: Can't find",res)
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
            isSearching = true
            populateFromCache(camera: camera, date: date,storageType: .smb)
        }
       
        //update the callers status because populate from cache will force a refresh
        remoteSearchListenr?.onRemoteSearchComplete(success: false, status: "Searching....")
        
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
            self.isSearching = false
            self.remoteSearchListenr?.onRemoteSearchComplete(success: true,status: "Search complete")
            self.showSetup = false
            self.done(withError: "")
        }
    }
    func doSearch(camera: Camera,date: Date,host: String,path: String,fileExt: String,credential: URLCredential){
        
        if searchDate != nil && Calendar.current.isDate(searchDate!, inSameDayAs: date) == false{
            results.removeAll()
            isSearching = true
            populateFromCache(camera: camera, date: date,storageType: .ftp)
        }
        DispatchQueue.main.async {
            self.doSearchImpl(camera: camera, date: date, host: host, path: path, fileExt: fileExt, credential: credential)
        }
    }
    private func doSearchImpl(camera: Camera,date: Date,host: String,path: String,fileExt: String,credential: URLCredential){
        //update the callers status because populate from cache will force a refresh
        
        remoteSearchListenr?.onRemoteSearchComplete(success: false, status: "Searching....")
        
        self.camera = camera
        self.host = host
        self.cred = credential
        statsView?.setCamera(camera: camera,storageType: .ftp)
        searchDate = date
        ftpPath = path
        self.fileExt = fileExt
    
        ftpSource = FtpDataSource(listener: self)
        
        let ss = camera.storageSettings
        
        var mode = FTPFileProvider.Mode.default
        if ss.xtras.count>0{
            let modeStr = ss.xtras[0]
            mode = FtpDataSource.getSelectedMode(selectedMode: modeStr)
        }
        
        if self.ftpSource!.connect(credential: credential, host: host,mode: mode){
            self.ftpSource!.searchPath(path: path,date: date) {
                self.isSearching = false
                //old code when using resursive in FilesProvider
                let strRes = "Found " + String(self.results.count) + " items"
                self.remoteSearchListenr?.onRemoteSearchComplete(success: true, status: strRes)
                
                RemoteLogging.log(item: "FtpStorageView " + strRes)
            }
        }else{
           
            self.actionComplete(success: false)
            self.remoteSearchListenr?.onRemoteSearchComplete(success: true, status: "Found " + String(self.results.count) + " items")
        }
    
    }
    
    func actionComplete(success: Bool){
        AppLog.write("FtpStorageViewModel:actionComplete",success)
        if !success{
            remoteSearchListenr?.onRemoteSearchComplete(success: false, status: "Failed to complete")
        }
    }
    func searchComplete(filePaths: [String]){
        DispatchQueue.main.async{
            //NEW callback from my resoursive code
            self.isSearching = false
            //old code when using resursive in FilesProvider
            let strRes = "Found " + String(filePaths.count) + " items"
            //make aure all files are showm
            
            for file in filePaths{
                self.fileFound(path: file, modified: self.searchDate)
            }
            
            self.remoteSearchListenr?.onRemoteSearchComplete(success: true, status: strRes)
            self.saveResults()
            if let sv = self.statsView{
                sv.refreshStats()
            
            }
            RemoteLogging.log(item: "FtpStorageView " + strRes)
        }
    }
    var validExts = ["mp4","avi","dav"]
    
    func fileFound(path: String,modified: Date?){
        DispatchQueue.main.async{
            self.fileFoundImpl(path: path, modified: modified)
        }
    }
    private func fileFoundImpl(path: String,modified: Date?){
        if let fd = modified{
           let sd = searchDate!
            if Calendar.current.isDate(fd, inSameDayAs: sd){
                AppLog.write("FtpStorageViewModel:fileFound matched day",path,modified)
                let fparts = path.components(separatedBy: ".")
                if fparts.count == 0{
                    return
                }
                let ext = fparts[fparts.count-1]
                
                if self.validExts.contains(ext){
                    
                    AppLog.write(">>>FtpStorageViewModel:fileFound matched day and ext",path,modified)
                    
                    
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
                    if let ftp = ftpSource{
                        rt.ftpMode = FtpDataSource.getFtpModeString(ftp)
                    }
                }
            }
            
        }
        
    }
    
    private func addIfNotInResults(rt: RecordToken) -> Bool{
        
        if results.count > 0{
            for r in results{
                if r.ReplayUri == rt.ReplayUri{
                    return false
                }
            }
        }
        results.append(rt)
        return true
    }
    
    func done(withError: String){
        //save results
        saveResults()
        refreshResults()
        
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
            let mode = FtpDataSource.getSelectedMode(selectedMode: token.ftpMode)
            
            let ftpDataSrc = FtpDataSource(listener: self)
            let ok = ftpDataSrc.connect(credential: token.creds!, host: token.remoteHost,mode: mode)
            if ok{
                ftpDataSrc.download(path: token.ReplayUri)
            }
        }
    }
    func downloadComplete(localFilePath: String,success: String?) {
        AppLog.write("FtpStorageViewModeldownloadComplete",success)
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
            if self.isSearching == false{
                self.remoteSearchListenr?.onRemoteSearchComplete(success: true, status: "Found " + String(self.results.count) + " items")
            }
        }
        
        
        
    }
    func directoryFound(dir: String){
        AppLog.write("FtpStorageViewModel:directoryFound",dir)
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
        
        /*
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
                AppLog.write("error reading FTP CSV")
            }
        }
         */
        let tmpResults = getCache(camera: camera, date: date, storageType: storageType)
        results.append(contentsOf: tmpResults)
        
        refreshResults()
        statsView?.refreshStats()
    }
    
    private func getCache(camera: Camera,date: Date,storageType: StorageType) -> [RecordToken]{
        var tmpResults = [RecordToken]()
        
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
                    
                
                    
                    tmpResults.append(rt)
                }
            }catch{
                AppLog.write("error reading FTP CSV")
            }
        }
        
        return tmpResults
    }
    private func saveResults(appendToCache: Bool  = false){
        var cache = getCache(camera: camera!, date: searchDate!, storageType: .ftp)
        
        var newItems = [RecordToken]()
        for rt in results{
            var doAdd = true
            for crt in cache{
                if rt.Time == crt.Time && rt.Token == crt.Token{
                    doAdd = false
                    break
                }
                
            }
            if doAdd{
                newItems.append(rt)
            }
        }
        for ni in newItems{
            cache.append(ni)
        }
        
        let newCache = cache.sorted{
            $0.getTime()! < $1.getTime()!
        }
        
        var csvResults = ""
        for rt in newCache{
            csvResults.append(rt.toFtpCsv())
            csvResults.append("\n")
        }
      
        let saveToPath = StorageHelper.getRemoteCacheFilePath(camera: camera!, searchDate: searchDate!, storageType: .ftp)
      
        do{
            
            try csvResults.write(toFile: saveToPath.path, atomically: true, encoding: String.Encoding.utf8)
            AppLog.write("Update cache for",searchDate)
        }catch{
            AppLog.write("Failed to save FTP events CSV",saveToPath)
        }
    }
    private func saveResultsOld(appendToCache: Bool  = false){
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
            AppLog.write(saveToPath.path)
            
            
            
        }catch{
            AppLog.write("Failed to save recording events CSV",saveToPath)
        }
    }
    
}

struct FtpStorageView: View, RemoteStorageActionListener, RemoteStorageTransferListener, VideoPlayerDimissListener {
    
    
    
    @ObservedObject var model = FtpStorageViewModel()
    var settingsView = RemoteStorageConfigView()
  
    var statsView = SDCardStatsView()
    var searchView = RemoteStorageSearchView()
    var rightPaneWidth = CGFloat(410.0)
    var barChart = SDCardBarChart()
    
    
    func dimissPlayer() {
        DispatchQueue.main.async{
            model.showPlayer = false
        }
 
    }
    func dismissAndShare(localPath: URL) {
        model.showPlayer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5,execute:{
            showShareSheet(with: [localPath])
        })
    }
    func setCamera(camera: Camera){
        //load ftp settings
        model.barchartModel = barChart.model
        //load settings
        camera.loadStorageSettings(storageType: "ftp")
        let ss = camera.storageSettings
        
        model.showSetup = ss.authenticated == false
        
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
        
        settingsView.setCamera(camera: camera,changeListener: searchView)
        
        
    }
    func searchComplete() {
        DispatchQueue.main.async {
            statsView.refreshStats()
        }
       
    }
    func doSearch(camera: Camera, date: Date, useCache: Bool) {
        AppLog.write("FtpStorageView:doSearch",date,camera.getDisplayName())
    
        barChart.reset()
        let st = camera.storageSettings.storageType
        if st.isEmpty{
        
        }
        else if st ==  "ftp"{
        
            let ftpSettings = settingsView.ftpSettingsView
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
        print("FtpSettingView:doDownload",token.toFtpCsv())
    }
    func doDelete(token: RecordToken) {
        
        
    }
    func doPlay(token: RecordToken) {
        if model.showPlayer{
            return
        }
        
        token.cameraName = model.camera!.getDisplayName()
        model.selectedToken = token
       
        model.videoPlayerSheet = VideoPlayerSheet()
        model.videoPlayerSheet.doInit(token: model.selectedToken!,listener: self)
        model.showPlayer = true
    }
    
    
    
    var body: some View {
        ZStack(){
            GeometryReader { fullView in
                let isLanscape = fullView.size.width - 320 > 600
                HStack{
                    VStack{
                        settingsView.disabled(model.isSearching)
                        Divider()
                        searchView
                        List{
                            ForEach(model.resultsByHour){ rc in
                                RecordCollectionView(rc: rc,camera: searchView.model.camera!,transferListener: self)
                            }
                        }.frame(alignment: .top)
                       
                       Spacer()
                       
                        HStack{
                            barChart.frame(height: 24,alignment: .center)
                        }.padding()
                    }
                  
                    if isLanscape{
                        Divider()
                        VStack{
                            if model.showSetup{
                                Text("Setup").appFont(.smallTitle).padding()
                                Text(model.storageHelp).appFont(.sectionHeader).padding()
                            }else{
                                Text("Statistics").appFont(.smallTitle)
                                statsView
                            }
                            Spacer()
                            //Text("Settings").appFont(.sectionHeader)
                            //ftpSettings
                        }.frame(width: rightPaneWidth)
                    }
                    
                }.hidden(model.showPlayer)
                
            }.fullScreenCover(isPresented: $model.showPlayer) {
                model.showPlayer = false
            } content: {
                //player
                model.videoPlayerSheet
            }
            
        }.onRotate { UIDeviceOrientation in
            //dimissPlayer()
        }
    }
}



struct FtpStorageView_Previews: PreviewProvider {
    static var previews: some View {
        FtpStorageView()
    }
}
