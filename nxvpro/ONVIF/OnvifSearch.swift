//
//  OnvifSearch.swift
//  TestMacUI
//
//  Created by Philip Bishop on 06/01/2022.
//

import Foundation

import CocoaAsyncSocket

protocol OnvifSearchListener{
    func onSearchStateChanged(camera: Camera,status: String)
    func onPartialResults(camera: Camera,partialResults: [RecordToken])
    func onSearchComplete(camera: Camera,allResults: [RecordToken],success: Bool,anyError: String)//fromCache or error
}

class OnvifSearch : NSObject, URLSessionDelegate{

    var onvifBase = BaseOnvifAuth()
    //var soapHeader = "soap_header"
    var soapFindRecordings = "soap_find_recordings"
    var soapFindResults = "soap_recording_results"
    var soapFindEvents = "soap_find_events"
    var soapEventsResults = "soap_events_results_min"
    var soapEventsResults2 = "soap_events_results"
    var soapRecordingConfig = "soap_recording_config"
    var soapReplay = "soap_replay"
    var soapSearchFunc = "soap_search_func"
    
    var listener: OnvifSearchListener?
    static var profileLookup = [String:RecordProfileToken]()
    static var recProfileTokenLookup = [String:String]()
    
    let opQueue = OperationQueue()
    
    override init(){
        super.init()
        //soapHeader = onvifBase.getXmlPacket(fileName: soapHeader)
        soapFindRecordings = onvifBase.getXmlPacket(fileName: soapFindRecordings)
        soapFindResults = onvifBase.getXmlPacket(fileName: soapFindResults)
        soapFindEvents = onvifBase.getXmlPacket(fileName: soapFindEvents)
        soapEventsResults = onvifBase.getXmlPacket(fileName: soapEventsResults)
        soapEventsResults2 = onvifBase.getXmlPacket(fileName: soapEventsResults2)
        soapRecordingConfig = onvifBase.getXmlPacket(fileName: soapRecordingConfig)
        soapReplay = onvifBase.getXmlPacket(fileName: soapReplay)
        soapSearchFunc = onvifBase.getXmlPacket(fileName: soapSearchFunc)
    }
    
    /*
    func getXmlPacket(fileName: String) -> String{
        if let filepath = Bundle.main.path(forResource: fileName, ofType: "xml") {
            do {
                let contents = try String(contentsOfFile: filepath)
                return contents
            } catch {
                print("Failed to load XML from bundle",fileName)
            }
        }
        return ""
    }
    
    func addAuthHeader(camera: Camera,soapPacket: String) -> String{
         if camera.password.isEmpty {
            return soapPacket
        }
        //camera.connectTime = Date()
        
        var sp = ""
        let auth = OnvifAuth(password: camera.password, cameraTime: camera.connectTime)
        
        sp = String(utf8String: soapHeader.cString(using: .utf8)!)!
        sp = sp.replacingOccurrences(of: "_USERNAME_", with: camera.user)
        sp = sp.replacingOccurrences(of: "_PWD_DIGEST_", with: auth.passwordDigest)
        sp = sp.replacingOccurrences(of: "_NONCE_", with: auth.nonce64)
        sp = sp.replacingOccurrences(of: "_TIMESTAMP_", with: auth.creationTime)
        
        var packetWithAuth = "";//"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        
        
        let cleanSoapPacket = soapPacket.replacingOccurrences(of: "\r\n",with: "\n")
        let lines = cleanSoapPacket.components(separatedBy: "\n");
        packetWithAuth += lines[0]//.trimmingCharacters(in: CharacterSet.newlines)
        packetWithAuth += "\n"
        packetWithAuth += sp
        for i in 1...lines.count-1{
            packetWithAuth += lines[i]//.trimmingCharacters(in: CharacterSet.newlines)
            packetWithAuth += "\n"
        }
        return packetWithAuth
    }
*/
    //MARK: Find Recording Ranges
    //Change to getRecording summary
    
    func searchForVideoDateRange(camera: Camera,callback: @escaping (Camera,Bool,String) -> Void){
        let function = "GetRecordingSummary"
        executeSearchFunc(function: function, camera: camera) { camera, ok, xmlPaths, anyError in
            if !ok{
                callback(camera,false,anyError)
            }
            
            /*
             tse:Summary/tt:DataFrom/2021-12-31T06:58:25Z
             tse:Summary/tt:DataUntil/2022-01-11T04:12:12Z
             tse:Summary/tt:NumberRecordings/1
             */
            let recordingProfile = RecordProfileToken()
            for xpath in xmlPaths{
                let parts = xpath.components(separatedBy: "/")
                if parts.count == 3{
                    let nparts = parts[1].components(separatedBy: ":")
                    guard nparts.count > 1 else{
                        continue
                    }
                    let tag = nparts[1]
                    if tag.hasSuffix("DataFrom"){
                        recordingProfile.earliestRecording = parts[2]
                    }else if tag.hasSuffix("DataUntil"){
                        recordingProfile.latestRecording = parts[2]
                    }else if tag.hasSuffix("NumberRecordings"){
                        recordingProfile.recordingImages = Int(parts[2])!
                    }
                }
            }
            
            camera.recordingProfile = recordingProfile
            
            self.updateCachedProfiles(camera: camera, profiles: [recordingProfile])
            
            callback(camera,true,"OK")
        }
    }
  
    func executeSearchFunc(function: String,camera: Camera,callback: @escaping (Camera,Bool,[String],String) -> Void){
        let action = "http://www.onvif.org/ver10/search/wsdl/"+function
        var soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapSearchFunc)
        soapPacket = soapPacket.replacingOccurrences(of: "_FUNC_", with: function)
        
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        let endpoint = URL(string: camera.searchXAddr)!
    
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                callback(camera,false,[String](),"Connect error");
                return
            }else{
                
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                
                    let resp = String(data: data!, encoding: .utf8)
                    print(resp)
                    
                    callback(camera,false,[String](),fparser.authFault)
                    return
                }
                
                let xmlParser = XmlPathsParser(tag: ":"+function+"Response")
                xmlParser.parseRespose(xml: data!)
            
                callback(camera,true,xmlParser.itemPaths,"OK" );
            }
        }
        task.resume()
    }
    
    func getRecordingProfileToken(camera: Camera){
        var action = "http://www.onvif.org/ver10/search/wsdl/FindRecordings"
        var soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapFindRecordings)
        
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        let endpoint = URL(string: camera.searchXAddr)!
    
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        //request.setValue("ExpectContinue", forHTTPHeaderField: "100")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        var retryCount = 0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                return
            }else{
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                    print("Failed to recording profile token",fparser.authFault)
                    return
                }
                let parser = SingleTagParser(tagToFind: ":SearchToken")
                parser.parseRespose(xml: data!)
                if parser.result.isEmpty == false {
                    self.getRecordingToken(camera: camera, searchToken: parser.result)
                }else{
                    print("Failed to recording profile token no token")
                }
            }
        }
        task.resume()
    }
    func getRecordingToken(camera: Camera,searchToken: String){
        let action = "http://www.onvif.org/ver10/search/wsdl/GetRecordingSearchResults"
        let searchPacket = soapFindResults.replacingOccurrences(of: "_TOKEN_",with: searchToken)
        let soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: searchPacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        
        let endpoint = URL(string: camera.searchXAddr)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Keep-Alive")
        request.setValue("ExpectContinue", forHTTPHeaderField: "100")
       
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
       
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
              
                return
            }else{
                let xmlParser = XmlPathsParser(tag: ":GetRecordingSearchResultsResponse")
                xmlParser.parseRespose(xml: data!)
                //tse:ResultList/tt:RecordingInformation/tt:RecordingToken/RecordMediaProfile000
                let xpaths = xmlParser.itemPaths
                for xpath in xpaths{
                    let path = xpath.components(separatedBy: "/")
                    if path.count == 3 && path[2]=="Searching"{
                        self.getRecordingToken(camera: camera, searchToken: searchToken)
                        return
                    }
                    if path .count == 4{
                        if path[2].hasSuffix(":RecordingToken"){
                            let rt = path[3]
                            //camera.recordProfileToken = rt
                            print(">>getRecordingToken",camera.getStringUid(),rt)
                            break
                        }
                    }
                }
                
            }
        }
        resultTask.resume()
    }
    /*
    func old_searchForVideoDateRange(camera: Camera,callback: @escaping (Camera,Bool,String) -> Void){
        var action = "http://www.onvif.org/ver10/search/wsdl/FindRecordings"
        var soapPacket = addAuthHeader(camera: camera, soapPacket: soapFindRecordings)
        
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        let endpoint = URL(string: camera.searchXAddr)!
    
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        //request.setValue("ExpectContinue", forHTTPHeaderField: "100")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        var retryCount = 0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                callback(camera,false,"Connect error");
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
                
                //self.saveSoapPacket(endpoint: endpoint, method: "find_recordings", xml: resp!)
                let fparser = FaultParser()
                fparser.parseRespose(xml: data!)
                if fparser.hasFault(){
                    callback(camera,false,fparser.authFault)
                    return
                }
                let parser = SingleTagParser(tagToFind: ":SearchToken")
                parser.parseRespose(xml: data!)
                if parser.result.isEmpty == false {
                    self.getRecordingTokens(camera: camera, searchToken: parser.result,retryCount: retryCount,callback: callback)
                }else{
                    callback(camera,false,"Invalid response from camera")
                }
                
            }
        }
        
        task.resume()
    }
    private func getRecordingTokensDelayed(camera: Camera,searchToken: String,retryCount: Int,callback: @escaping (Camera,Bool,String) -> Void){
        let dq = DispatchQueue(label: camera.getStringUid()+String(retryCount))
        dq.asyncAfter(deadline: .now() + 1,execute:{
            self.getRecordingTokens(camera: camera,searchToken: searchToken,retryCount: retryCount + 1,callback: callback)
        })
    }
    private func getRecordingTokens(camera: Camera,searchToken: String,retryCount: Int,callback: @escaping (Camera,Bool,String) -> Void){
        
        print("OnvifSearch:getRecordingTokens retryCount",retryCount,camera.getStringUid())
        
        let action = "http://www.onvif.org/ver10/search/wsdl/GetRecordingSearchResults"
        let searchPacket = soapFindResults.replacingOccurrences(of: "_TOKEN_",with: searchToken)
        let soapPacket = addAuthHeader(camera: camera, soapPacket: searchPacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        
        let endpoint = URL(string: camera.searchXAddr)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Keep-Alive")
        request.setValue("ExpectContinue", forHTTPHeaderField: "100")
       
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
       
        let resultTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                print(error?.localizedDescription ?? "No data")
                callback(camera,false,"Connect error");
                return
            }else{
                if self.handleGetRecordingsResponse(camera: camera,data: data, callback: callback) == false{
                    if retryCount < 10{
                        self.getRecordingTokensDelayed(camera: camera,searchToken: searchToken,retryCount: retryCount + 1,callback: callback)
                    }
                }
                
            }
        }
        resultTask.resume()
    }
    func handleGetRecordingsResponse(camera: Camera,data: Data?,callback: @escaping (Camera,Bool,String) -> Void) -> Bool{
        let resp = String(data: data!, encoding: .utf8)
        
        var rparser = RecordingsResultsParser()
        rparser.parseRespose(xml: data!)
        if rparser.hasResult(){
            print(resp)
            
            print("searchForVideoRange has results",camera.getStringUid())
            self.updateCachedProfiles(camera: camera,profiles: rparser.allResults);
            callback(camera,true,"OK");
            return true
        }
        
        var sparser = RecordingsXmlParser()
        sparser.parseRespose(xml: data!)
        if sparser.searchState.isEmpty == false{
            callback(camera,false,"Searching...");
            print("searchForVideoRange searching for results",camera.getStringUid())
            
            return false
            
        }else{
            callback(camera,false,"No results");
            print("searchForVideoRange has NO results",camera.getStringUid())
        }
        return true
    }*/
    func hasProfile(camera: Camera) -> Bool{
        return getProfile(camera: camera) != nil
    }
    func getProfile(camera: Camera) -> RecordProfileToken?{
        var id = camera.getStringUid()
        return OnvifSearch.profileLookup[id]
    }
    func updateCachedProfiles(camera: Camera,profiles: [RecordProfileToken]){
        
        if camera.isNvr(){
            
            for vcam in camera.vcams{
                let id = vcam.getStringUid()
                if OnvifSearch.profileLookup[id] == nil{
                    OnvifSearch.profileLookup[id] = profiles[0]
                }
                /*
                var found = false
                for rt in profiles{
                   if rt.recordingToken.hasSuffix("0"+String(vcam.vcamId)){
                        let id = vcam.getStringUid()
                        profileLookup[id] = rt
                        found = true
                    }
                    if found{
                        break
                    }
                }
                 */
                
            }
        }else{
            let id = camera.getStringUid()
            OnvifSearch.profileLookup[id] = profiles[0]
        }
        
        
    }
    //MARK: Find recordings
    var allResults = [RecordToken]()
    var searchDay: Date?
    var searchCount = 0
    var appendToCache = false
    
    func doSearchForEvents(camera: Camera,sdate: Date,edate: Date,useCache: Bool = false,checkCacheOnly: Bool = false){
    
        searchDay = sdate
        allResults.removeAll()
        useMinXml = false
        searchCount = 0
        
        if useCache{
            if populateFromCache(camera: camera){
                
                return
            }
            if checkCacheOnly{
                listener?.onSearchComplete(camera: camera,allResults: allResults, success: true, anyError: "")
                return
            }
        }
        
        listener?.onSearchStateChanged(camera: camera,status: "Searching...")
        
        _searchForEvents(camera: camera, sdate: sdate, edate: edate)
        
    }
    
    
    func checkForRecentEvents(camera: Camera,minutesAgo: Int){
        let sdate = Calendar.current.date(byAdding: .minute, value: (minutesAgo * -1), to: Date())!
        let edate = Date()
        searchDay = sdate
        _searchForEvents(camera: camera, sdate: sdate, edate: edate)
    }
    
    var searchStartedAt: Date?
    let searchTimeout = 60
    private func _searchForEvents(camera: Camera,sdate: Date,edate: Date){
        
        print("SEARCH FOR EVENTS",sdate,edate)
        
        searchCount += 1
        
        searchStartedAt = Date()
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        let sdateStr = df.string(from: sdate)
        let edateStr = df.string(from: edate)
        
        var action = "http://www.onvif.org/ver10/search/wsdl/FindEvents"
        var soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapFindEvents)
        
        soapPacket = soapPacket.replacingOccurrences(of: "_START_DATETIME_", with: sdateStr)
        soapPacket = soapPacket.replacingOccurrences(of: "_END_DATETIME_", with: edateStr)
        
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        let endpoint = URL(string: camera.searchXAddr)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Close")
        
    
        let config  = URLSessionConfiguration.default
        config.urlCache = nil
        let session = URLSession(configuration: config,delegate: self,delegateQueue: opQueue)
       
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                let error=(error?.localizedDescription ?? "Connection failed")
                self.listener?.onSearchStateChanged(camera: camera,status: "Search fault: " + error)
                
                if self.allResults.count > 0{
                    self.saveEvents(camera: camera)
                }
                
                self.listener?.onSearchComplete(camera: camera,allResults: self.allResults, success: false, anyError: error)
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
                
                let xmlParser = XmlPathsParser(tag: "FindEventsResponse")
                xmlParser.parseRespose(xml: data!)
                
                var hasToken = false
                
                let xpaths = xmlParser.itemPaths
                for xpath in xpaths{
                    //tse:SearchToken/000000004801
                    let path = xpath.components(separatedBy: "/")
                    if path[0].contains(":SearchToken"){
                        let searchToken = path[1]
                        hasToken = true
                        print("TOKEN",searchToken)
                        
                        self.listener?.onSearchStateChanged(camera: camera,status: "Search token obtained")
                        
                        self.getSearchResults(camera: camera, token: searchToken,edate: edate)
                    }
                }
                if !hasToken{
                    print("SEARCH TOKEN NOT FOUND")
                    print(xmlParser.itemPaths)
                    var info = "Info no token"
                    
                    
                    var doRetry = false
                    let fparser = XmlPathsParser(tag: "Fault")
                    fparser.parseRespose(xml: data!)
                    for xpath in fparser.itemPaths{
                        //soap:Reason/soap:Text/Action Failed
                        //soap:Detail/soap:Text/Device is unable to create a new search session.
                        let path = xpath.components(separatedBy: "/")
                        if path[0].hasSuffix(":Reason") || path[0].hasSuffix(":Detail"){
                            if path.count>2 && path[2].isEmpty ==  false {
                                info = path[2]
                               /*
                                if self.useMinXml{
                                   doRetry = true
                                }
                                self.useMinXml = false
                                */
                            }
                        }
                    }
                    if doRetry{
                       // info = "_DRT_" + info
                    }
                    
                    //must save before callback which will reset results to empty
                    if self.allResults.count>0{
                        self.saveEvents(camera: camera)
                    }
                    
                    self.listener?.onSearchComplete(camera: camera,allResults: self.allResults, success: true, anyError: info)
                    
                   
                        
                }
                
            }
        }
        task.resume()
    }
    var currentTask: URLSessionDataTask?
    var useMinXml = false
    func getSearchResults(camera: Camera,token: String,edate: Date){
        
        currentTask?.cancel()
        
        let action = "http://www.onvif.org/ver10/search/wsdl/GetEventSearchResults"
        let xmlToUse = useMinXml ? soapEventsResults : soapEventsResults2
        let searchPacket = xmlToUse.replacingOccurrences(of: "_TOKEN_",with: token)
        let soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: searchPacket)
        var contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\""
        let endpoint = URL(string: camera.searchXAddr)!
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Connection", forHTTPHeaderField: "Keep-Alive")
        request.setValue("ExpectContinue", forHTTPHeaderField: "100")
        
        let config  = URLSessionConfiguration.default
        config.urlCache = nil
        let session = URLSession(configuration: config,delegate: self,delegateQueue: opQueue)
       
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
         
        currentTask = session.dataTask(with: request) { data, response, error in
            if error != nil {
                let error=(error?.localizedDescription ?? "Connection failed")
                self.listener?.onSearchStateChanged(camera: camera,status: "Search fault: " + error)
                self.listener?.onSearchComplete(camera: camera,allResults: self.allResults, success: false, anyError: error)
                return
            }else{
                let resp = String(data: data!, encoding: .utf8)
                
                let xmlParser = XmlPathsParser(tag: "GetEventSearchResultsResponse",separator: "|")
                xmlParser.parseRespose(xml: data!)
                
                let xpaths = xmlParser.itemPaths
                
                if xpaths.count == 0 {
                    if !self.useMinXml && self.searchCount == 1 && self.allResults.count==0{
                        self.useMinXml = true
                        //restart
                        self.listener?.onSearchStateChanged(camera: camera,status: "Retrying connection")
                        DispatchQueue(label: token).asyncAfter(deadline: .now() + 5, execute: {
                            self._searchForEvents(camera: camera, sdate: self.searchDay!, edate: edate)
                        })
                       
                        return
                    }
                    
                    self.listener?.onSearchComplete(camera: camera,allResults: self.allResults, success: false, anyError: "Camera rejected request")
                    
                }
                
                let eventsFactory = EventsResultFactory()
                
                var isSearching = false
                var lastEventTime = ""
                for xpath in xpaths{
                    eventsFactory.consumeXPath(xpath: xpath,pathSeparator: xmlParser.pathSeparator)
                    //tt:SearchState/Searching
                
                    let path = xpath.components(separatedBy: "/")
                    if path.count == 3{
                        if path[1].contains(":SearchState"){
                            let searchState = path[2]
                            print("SEARCH STATE",searchState)
                            
                            if searchState == "Searching"{
                                isSearching = true
                            }
                        }
                    }else if path.count > 3{
                        if path[2].contains(":Time"){
                            lastEventTime = path[3]
                        }
                    }
                }
               
                let cp = camera.selectedProfile()
                let rta = eventsFactory.getRecordingEvents(profileToken: cp!.token)
                //update results if not exists
                self.updateResults(partialResults: rta)
                self.listener?.onPartialResults(camera: camera,partialResults: eventsFactory.recordingEvents)
               
                
                if isSearching && lastEventTime.isEmpty == false{
                    print("Search not complete",lastEventTime)
                    
                    self.listener?.onSearchStateChanged(camera: camera,status: "Receiving results...")
                    
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    let sdate = df.date(from: lastEventTime)!.withAddedMinutes(minutes: 1)
                    //print("Search not complete",lastEventTime,sdate)
                    
                    let waitFor = self.useMinXml ? 1.0 : 2.0
                    
                    DispatchQueue(label: token).asyncAfter(deadline: .now() + waitFor, execute: {
                        //self._searchForEvents(camera: camera,sdate: sdate,edate: edate)
                        self.getSearchResults(camera: camera,token: token,edate: edate)
                    })
                   
                    
                }else{
                    print("COMPLETE lastEvent",lastEventTime)
                    
                    
                    let howLong = abs(self.searchStartedAt!.timeIntervalSinceNow)
                    print("COMPLETE took",howLong)
                    
                    let completeTag = howLong > 30 ? "TIMEOUT" : ""
                    
                    self.listener?.onSearchStateChanged(camera: camera,status: "Search ended after " + String(howLong))
                    self.listener?.onSearchComplete(camera: camera,allResults: self.allResults, success: true, anyError: completeTag)
                    
                    if self.allResults.count>0{
                        self.saveEvents(camera: camera)
                    }
                }
            }
        }
        currentTask?.resume()
    }
    
    private func updateResults(partialResults:  [RecordToken]){
        for nr in partialResults{
            var addResults = true
            for r in allResults{
                if r.Time == nr.Time{
                    addResults = false
                    break
                }
            }
            if addResults{
                allResults.append(nr)
            }
        }
    }
    static var CACHED_FLAG = "from_cache"
    func getResumeDateFromCache(camera: Camera,date: Date) -> Date?{
        let cachedPath = getCacheFilePath(camera: camera,date: date)
        var latestDate: Date?
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
                    rt.fromCsv(line: line)
                    let rtd = rt.getTime()!
                    if Calendar.current.isDate(date, inSameDayAs: rtd){
                        latestDate = rt.getTime()
                    }
                }
            }catch{
                print("Failed to load recording events CSV",cachedPath)
            }
        }
        if latestDate != nil{
            return latestDate!.withAddedMinutes(minutes: 1)
        }
        return latestDate
    }
    private func populateFromCache(camera: Camera) -> Bool{
        let cachedPath = getCacheFilePath(camera: camera,date: searchDay!)
        var tmpResults = [RecordToken]()
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
                    rt.fromCsv(line: line)
                    
                    let rtd = rt.getTime()!
                    if Calendar.current.isDate(searchDay!, inSameDayAs: rtd){
                        tmpResults.append(rt)
                        if rt.ReplayUri.isEmpty{
                           //enabled at 6.5.3.3
                            getReplayUri(camera: camera, recordToken: rt)
                        }
                    }
                }
                camera.tmpSearchResults = tmpResults
                updateResults(partialResults: tmpResults)
                listener?.onSearchComplete(camera: camera,allResults: allResults, success: true, anyError: OnvifSearch.CACHED_FLAG)
                return true
            }catch{
                print("Failed to load recording events CSV",cachedPath)
            }
        }
        return false
    }
    private func getCacheFilePath(camera: Camera,date: Date) -> URL{
        let startOfOay = Calendar.current.startOfDay(for: date)
        
        let sdCardRoot = FileHelper.getSdCardStorageRoot()
        var frmt = DateFormatter()
        frmt.dateFormat="yyyyMMdd"
        let dayStr =  frmt.string(from: startOfOay)
        let camUid = camera.isVirtual ? camera.getBaseFileName() : camera.getStringUid()
        let filename = camUid + "_" +  dayStr + ".csv"
        let saveToPath = sdCardRoot.appendingPathComponent(filename)
        return saveToPath
    }
    private func saveEvents(camera: Camera){
        //searchDay will be nil when we are checking for recent events
        if searchDay == nil{
            return
        }
        let startOfOay = Calendar.current.startOfDay(for: searchDay!)
        
        let saveToPath = getCacheFilePath(camera: camera,date: startOfOay)
        
        var csvResults = ""
        for rt in allResults{
            rt.day = startOfOay
            
            csvResults.append(rt.toCsv())
            csvResults.append("\n")
        }
        print("OnvifSearchSaveEvents apendToCache",appendToCache)
        
        do{
            var writeToFile = true
            if appendToCache{
                
               
                
                if let fileUpdater = try? FileHandle(forUpdating: saveToPath) {

                    // Function which when called will cause all updates to start from end of the file
                    fileUpdater.seekToEndOfFile()
                    // Which lets the caller move editing to any position within the file by supplying an offset
                    fileUpdater.write(csvResults.data(using: .utf8)!)

                    // Once we convert our new content to data and write it, we close the file and that’s it!
                    fileUpdater.closeFile()
                    
                    writeToFile = false
                }
            }
            if writeToFile{
                try csvResults.write(toFile: saveToPath.path, atomically: true, encoding: String.Encoding.utf8)
            }
            print(saveToPath.path)
        }catch{
            print("Failed to save recording events CSV",saveToPath)
        }
    }
    //MARK: Get Replay URL
    static var replayLookup = [String:String]()
    
    func getReplayUri(camera: Camera,recordToken: RecordToken){
        let key = camera.getStringUid()+"_"+recordToken.Token
        
        if let uri = OnvifSearch.replayLookup[key]{
            recordToken.ReplayUri = uri
            print("OnvidSearch:replayUri",uri,recordToken.TrackToken)
            return
        }
        var function = "GetReplayUri"
        var action = "http://www.onvif.org/ver10/replay/wsdl/" + function
        var recPacket = soapReplay.replacingOccurrences(of: "_REC_TOKEN_",with: recordToken.Token)
        var soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: recPacket)
        
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
        
        let xaddr = camera.replayXAddr
        
        if let endpoint = URL(string: xaddr) {
            
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Connection", forHTTPHeaderField: "Close")
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            
            request.httpBody = soapPacket.data(using: String.Encoding.utf8)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    let errMsg = (error?.localizedDescription ?? "Connect error")
                    print(errMsg)
                    //callback(camera,false,[errMsg]);
                    return
                }else{
                    let resp = String(data: data!, encoding: .utf8)
                    
                    let xmlParser = XmlPathsParser(tag: ":"+function+"Response")
                    xmlParser.parseRespose(xml: data!)
                    let xmlPaths = xmlParser.itemPaths
                    if xmlPaths.count == 1{
                        let path = xmlPaths[0].components(separatedBy: "Uri/")
                        
                        if path.count == 2{
                            let replayUri = path[1]
                            recordToken.ReplayUri = replayUri
                            OnvifSearch.replayLookup[key] = replayUri
                            
                            print("OnvidSearch:replayUri",replayUri,recordToken.TrackToken)
                        }
                    }
                    //set the replayUrl if valid
                    //replayLookup[key] = replayUri
                    //recordToken.replayUri = replayUri
                }
            }
            
            task.resume()
        }
        
    }
    
    //MARK: Storage configuration for RecordToken
    func getRecordingConfiguration(camera: Camera,token: RecordToken,callback: @escaping (Camera,[String],String)->Void){
        let getFunc = "GetRecordingConfiguration"
        let action = "http://www.onvif.org/ver10/recording/wsdl/"+getFunc
        
        let apiUrl = URL(string: camera.recordingXAddr)!
        
        var soapPacket = onvifBase.addAuthHeader(camera: camera, soapPacket: soapRecordingConfig).replacingOccurrences(of: "\r", with: "")
        soapPacket = soapPacket.replacingOccurrences(of: "_TOKEN_", with: token.Token)
        
        print(soapPacket)
        
        let contentType = "application/soap+xml; charset=utf-8; action=\"" + action + "\"";
      
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.setValue("Connection", forHTTPHeaderField: "Close")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        request.httpBody = soapPacket.data(using: String.Encoding.utf8)
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: request) { data, response, error in
            if error != nil {
                let error = error?.localizedDescription ?? "Connect error"
                callback(camera,[String](),error)
                print(error)
                return
            }else{
                let parser = FaultParser()
                parser.parseRespose(xml: data!)
                if(parser.hasFault()){
                    callback(camera,[String](),parser.authFault)
                    return
                }
                
                let resp = String(data: data!, encoding: .utf8)
                //self.saveSoapPacket(endpoint: apiUrl, method: getFunc, xml: resp!)
                
                
                var keyValuePairs = [String:String]()
                let xmlParser = XmlPathsParser(tag: ":"+getFunc+"Response")
                xmlParser.parseRespose(xml: data!)
                let xpaths = xmlParser.itemPaths
                
                callback(camera,xpaths,"")
                
            }
        }
        task.resume()
    }
}
