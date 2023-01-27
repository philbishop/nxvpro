//
//  FtpDataSource.swift
//  TestMacUI
//
//  Created by Philip Bishop on 27/01/2022.
//

import Foundation
import FilesProvider

protocol FtpDataSourceListener{
    func actionComplete(success: Bool)
    func fileFound(path: String,modified: Date?)
    func searchComplete(filePaths: [String])
    func directoryFound(dir: String)
    func downloadComplete(localFilePath: String,success: String?)
    func done()
}

class FtpDataSource : FileProviderDelegate{
    
    
    var listener: FtpDataSourceListener
    var ftpProvider: FTPFileProvider!
    
    init(listener: FtpDataSourceListener){
        self.listener = listener
    }
    

    
    func connect(credential: URLCredential,host: String) -> Bool{
        
        guard let ftpProv = FTPFileProvider(baseURL: URL(string:"ftp://"+host)!, mode: .default, credential: credential, cache: nil) else {
            listener.actionComplete(success: false)
            return false//or some error handling
        }
        ftpProv.delegate = self
        ftpProvider = ftpProv
        
        return true
        
        
    }
    var downloadComplete = false
    func download(path: String){
        
        AppLog.write("FtpDataSource:download",path)
        let targetUrl = StorageHelper.getLocalFilePath(remotePath: path)
        
        if targetUrl.1{
            //let fpath = targetUrl.0.path
            listener.downloadComplete(localFilePath: targetUrl.0.path,success: nil)
            return
        }
        AppLog.write("FtpDataSource:download",path,targetUrl)
        
        downloadComplete = false
        
        ftpProvider.copyItem(path: path, toLocalURL: targetUrl.0) { error in
            if !self.downloadComplete{
                self.downloadComplete = true
                AppLog.write("FtpDataSource: Download complete",error)
                let msg = error == nil ? nil : error!.localizedDescription
                self.listener.downloadComplete(localFilePath: targetUrl.0.path,success: msg)
            }
        }
    }

    func searchDirs(path: String,recursive: Bool = false){
        let predicate = NSPredicate(value: true)
        ftpProvider.searchFiles(path: path, recursive: recursive, query: predicate) { file in
            if file.isDirectory{
                self.listener.directoryFound(dir: file.path)
            }else if file.isRegularFile{
                self.listener.fileFound(path: file.path, modified: file.modifiedDate)
            }
        } completionHandler: { files, error in
            self.listener.done()
        }
    }
    
    func searchPath(path: String,date: Date,callback: @escaping ()->Void){
        
        let searcher = FtpFileSearch(ftpProvider: ftpProvider,listener: listener)
        searcher.start(path: path, date: date)
        //self.listener.done()
        //callback()
    }
    
    func _searchPath(path: String,date: Date,callback: @escaping ()->Void){
        //TO TRY ftpProvider.searchFiles
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local

        // Get today's beginning & end
        let dateFrom = calendar.startOfDay(for: date) // eg. 2016-10-10 00:00:00
        let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)
        // Note: Times are printed in UTC. Depending on where you live it won't print 00:00:00 but it will work with UTC times which can be converted to local time

        let fromPredicate = NSPredicate(format: "modifiedDate >= %@", dateFrom as NSDate)
        let toPredicate   = NSPredicate(format: "modifiedDate < %@",  dateTo! as NSDate)
        
        let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])
       
        let predicate = datePredicate// NSPredicate(value: true)//
        ftpProvider.searchFiles(path: path, recursive: true, query: predicate) { file in
            if file.isRegularFile{
                #if DEBUG
                AppLog.write("FtpDataSource >>",file.path)
                #endif
                self.listener.fileFound(path: file.path, modified: file.modifiedDate)
            }else{
                #if DEBUG
                AppLog.write("FtpDataSource",file.path)
                #endif
            }
        } completionHandler: { files, error in
            DispatchQueue.main.async {
                self.listener.done()
                callback()
            }
            
        }

        
        //handlePath(path: path)
    }
    
    private func handlePath(path: String){
        ftpProvider.contentsOfDirectory(path: path) { files, error in
            if error != nil{
                self.listener.actionComplete(success: false)
            }else{
                if files.count == 0{
                    AppLog.write(">>FtpDataSource exhausted -> Done")
                    DispatchQueue.main.async{
                        self.listener.done()
                    }
                    return
                }
                for file in files{
                   // AppLog.write(file)
                    if file.isDirectory{
                        //self.listener.directoryFound(dir: file.path)
                        self.handlePath(path: file.path)
                    }else{
                        DispatchQueue.main.async{
                        
                            self.listener.fileFound(path: file.path,modified: file.modifiedDate)
                        }
                    }
                }
               
            }
            //self.listener.done()
        }
    }
    //MARK: FilesProviderDelegate
    func fileproviderSucceed(_ fileProvider: FileProviderOperations, operation: FileOperationType) {
        AppLog.write("fileproviderSucceed",operation)
        listener.actionComplete(success: true)
    }
    func fileproviderFailed(_ fileProvider: FileProviderOperations, operation: FileOperationType, error: Error) {
        AppLog.write("fileproviderFailed",operation,error)
        listener.actionComplete(success: false)
    }
    func fileproviderProgress(_ fileProvider: FileProviderOperations, operation: FileOperationType, progress: Float) {
        //AppLog.write("fileproviderProgress",operation,progress)
    }

}
