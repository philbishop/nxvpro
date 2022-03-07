//
//  FtpFileSeach.swift
//  nxvpro
//
//  Created by Philip Bishop on 07/03/2022.
//

import Foundation
import FilesProvider

class FtpFileSearch{
    
    var itemsFound = [String]()
    var ftpProvider: FTPFileProvider
    var subsAdded = [String]()
    var subsCompleted = [String]()
    var hasSubs = false
    var listener: FtpDataSourceListener
    init(ftpProvider: FTPFileProvider,listener: FtpDataSourceListener){
        self.ftpProvider = ftpProvider
        self.listener = listener
    }
    
    func start(path: String,date: Date){
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local

        // Get today's beginning & end
        let dateFrom = calendar.startOfDay(for: date) // eg. 2016-10-10 00:00:00
        let dateTo = calendar.date(byAdding: .day, value: 1, to: dateFrom)
        // Note: Times are printed in UTC. Depending on where you live it won't print 00:00:00 but it will work with UTC times which can be converted to local time

        let fromPredicate = NSPredicate(format: "modifiedDate >= %@", dateFrom as NSDate)
        let toPredicate   = NSPredicate(format: "modifiedDate < %@",  dateTo! as NSDate)
        
        let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])
       
        let predicate = datePredicate
        
        ftpProvider.searchFiles(path: path, recursive: false, query: predicate) { file in
            if file.isRegularFile{
                if file.path.hasSuffix(".mp4"){
                    self.itemsFound.append(file.path)
                    self.listener.fileFound(path: file.path, modified: file.modifiedDate)
                }
            }else{
                self.hasSubs = true
                self.searchSub(path: file.path)
            }
        } completionHandler: { files, error in
           
            if self.hasSubs{
                print("FtpFileSearch:end",files.count,error)
                print("FtpFileSearch:hasSubs",self.hasSubs)
            }else{
                self.listener.done()
                self.listener.searchComplete(filePaths: [])
            }
            
        }
        
    }
    private func searchSub(path: String){
        print("FtpFileSearch:sub >> ",path)
        subsAdded.append(path)
        let predicate = NSPredicate(value: true)
        ftpProvider.searchFiles(path: path, recursive: false, query: predicate) { file in
            if file.isRegularFile{
                if file.path.hasSuffix(".mp4"){
                    self.itemsFound.append(file.path)
                    self.listener.fileFound(path: file.path, modified: file.modifiedDate)
                    print("FtpFileSearch",file.path)
                }
            }else{
                
                self.searchSub(path: file.path)
            }
        } completionHandler: { files, error in
            self.subsCompleted.append(path)
            
            if self.subsAdded.count == self.subsCompleted.count{
                print("FtpFileSearch:subEnd isComplete check",self.subsAdded.count,self.subsCompleted.count,self.itemsFound.count)
                self.listener.done()
                self.listener.searchComplete(filePaths: self.itemsFound)
            }
        }
    }
}
