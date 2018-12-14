//  CrashManager.swift

import Foundation
import UIKit

private let crashCount = 2
private let timeout = 10000

enum CrashPathEnum:String {
    case signalCrashPath = "SignaCrash"
    case nsExceptionCrashPath = "NSExceptionCrash"
}

//MARK: - Crash处理总入口,请留意不要集成多个crash捕获，NSSetUncaughtExceptionHandler可能会被覆盖.NSException的crash也会同时生成一个signal异常信息
func crashHandle(crashContentAction:@escaping ([String])->Void){
    DispatchQueue.global().async {
        
        CrashManager.deleteAllFilesIfMoreThan24H()
        
        if CrashManager.readAllCrashInfo().count > crashCount {
            //如果崩溃信息不为空，则对崩溃信息进行下一步处理
            crashContentAction(CrashManager.readAllCrashInfo())
        }
    }
    //注册signal,捕获相关crash
    registerSignalHandler()
    //注册NSException,捕获相关crash
    registerUncaughtExceptionHandler()
}

class CrashManager: NSObject {

    //MARK: - 保存崩溃信息
    class func  saveCrash(appendPathStr:CrashPathEnum,exceptionInfo:String)
    {
        let filePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first?.appending("/\(appendPathStr.rawValue)")
        
        if let crashPath = filePath{
            
            if !FileManager.default.fileExists(atPath: crashPath) {
                
                try? FileManager.default.createDirectory(atPath: crashPath, withIntermediateDirectories: true, attributes: nil)
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMddHHmmss"
            let dateString = dateFormatter.string(from: Date())
            
            let crashFilePath = crashPath.appending("/\(dateString).log")
            
            try? exceptionInfo.write(toFile: crashFilePath, atomically: true, encoding: .utf8)
        }
    }

    //MARK: - 获取所有的log列表
    class func CrashFileList(crashPathStr:CrashPathEnum) -> [String] {
        let pathcaches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory = pathcaches[0]
        let crashPath = cachesDirectory.appending("/\(crashPathStr.rawValue)")
        
        let fileManager = FileManager.default
        
        var logFiles: [String] = []
        let fileList = try? fileManager.contentsOfDirectory(atPath: crashPath)
        if let list = fileList {
            for fileName in list {
                if let _ = fileName.range(of: ".log") {
                    logFiles.append(crashPath+"/"+fileName)
                }
            }
        }
        
        return logFiles
    }

    //MARK: - 读取所有的崩溃信息
    class func readAllCrashInfo() -> [String] {
        var crashInfoArr:[String] = Array()
        
        //获取signal崩溃文件
        for signalPathStr in CrashFileList(crashPathStr: .signalCrashPath){
            if let content = try? String(contentsOfFile: signalPathStr, encoding: .utf8) {
                crashInfoArr.append(content)
            }
        }
        //获取NSexception崩溃文件
        for exceptionPathStr in CrashFileList(crashPathStr: .nsExceptionCrashPath){
            if let content = try? String(contentsOfFile: exceptionPathStr, encoding: .utf8){
                crashInfoArr.append(content)
            }
        }
        
        return crashInfoArr
    }
    
    //MARK: - 删除所有崩溃信息文件信息
    class func deleteAllCrashFile(){
        //删除signal崩溃文件
        for signalPathStr in CrashFileList(crashPathStr: .signalCrashPath){
            try? FileManager.default.removeItem(atPath: signalPathStr)
        }
        //删除NSexception崩溃文件
        for exceptionPathStr in CrashFileList(crashPathStr: .nsExceptionCrashPath){
            try? FileManager.default.removeItem(atPath: exceptionPathStr)
        }
    }
    
    //MARK: - 删除单个崩溃信息文件
    class func DeleteCrash(crashPathStr:CrashPathEnum, fileName: String) {
        let pathcaches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory = pathcaches[0]
        let crashPath = cachesDirectory.appending("/\(crashPathStr)")
        
        let filePath = crashPath.appending("/\(fileName)")
        let fileManager = FileManager.default
        try? fileManager.removeItem(atPath: filePath)
    }
    
    //MARK: - 读取单个文件崩溃信息
    class func ReadCrash(crashPathStr:CrashPathEnum, fileName: String) -> String? {
        let pathcaches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        let cachesDirectory = pathcaches[0]
        let crashPath = cachesDirectory.appending("/\(crashPathStr)")
        
        let filePath = crashPath.appending("/\(fileName)")
        let content = try? String(contentsOfFile: filePath, encoding: .utf8)
        return content
    }
    
    //MARK: - 超过24小时，清空崩溃所有文件
    class func deleteAllFilesIfMoreThan24H() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYYMMddHHmmss"
        let nowString = dateFormatter.string(from: Date())
        let now = Int(nowString) ?? 0
        
        var dateArray:[Int] = []
        for crashInfo in CrashManager.readAllCrashInfo() {
            let dateString = crashInfo.replacingOccurrences(of: ".log", with: "")
            if let date = Int(dateString) {
                dateArray.append(date)
            }
        }
        
        for date in dateArray {
            guard (now-date) < timeout else {
                CrashManager.deleteAllCrashFile()
                return
            }
        }
    }
    
    //MARK: - 删除所以本地持久化所有数据
    class func deleteAllFilesUnderDocumentsLibraryCaches() {
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        let libraryDirectory = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
        
        let filePathsToRemove = [documentsDirectory,libraryDirectory,cachesDirectory]
        let fileMgr = FileManager.default
        for filePath in filePathsToRemove {
            if let filePathc = filePath,fileMgr.fileExists(atPath: filePathc) {
                let subFileArray = try? fileMgr.contentsOfDirectory(atPath: filePathc)
                if subFileArray != nil {
                    for subFileName in subFileArray! {
                        let subFilePath = filePathc.appending("/\(subFileName)")
                        try? fileMgr.removeItem(atPath: subFilePath)
                    }
                }
            }
        }
    }
}
//获取设备型号
extension UIDevice {
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        switch identifier {
            case "iPod5,1":                                 return "iPod Touch 5"
            case "iPod7,1":                                 return "iPod Touch 6"
            case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
            case "iPhone4,1":                               return "iPhone 4s"
            case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
            case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
            case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
            case "iPhone7,2":                               return "iPhone 6"
            case "iPhone7,1":                               return "iPhone 6 Plus"
            case "iPhone8,1":                               return "iPhone 6s"
            case "iPhone8,2":                               return "iPhone 6s Plus"
            case "iPhone8,4":                               return "iPhone SE"
            case "iPhone9,1":                               return "iPhone 7 (国/港/日)"
            case "iPhone9,2":                               return "iPhone 7 Plus (港/国)"
            case "iPhone9,3":                               return "iPhone 7 (美/台)"
            case "iPhone9,4":                               return "iPhone 7 Plus (美/台)"
            case "iPhone10,1":                              return "iPhone 8 (国行(A1863)/日行(A1906))"
            case "iPhone10,2":                              return "iPhone 8 Plus (国行(A1864)/日行(A1898))"
            case "iPhone10,3":                              return "iPhone X (国行(A1865)/日行(A1902))"
            case "iPhone10,4":                              return "iPhone 8 (美版(Global/A1905))"
            case "iPhone10,5":                              return "iPhone 8 Plus (美版(Global/A1897))"
            case "iPhone11,2":                              return "iPhone XS"
            case "iPhone11,4","iPhone11,6":                 return "iPhone XS Max"
            case "iPhone11,8":                              return "iPhone XR"
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
            case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
            case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
            case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7"
            case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9"
            case "iPad6,11":                                return "iPad 5 (WiFi)"
            case "iPad6,12":                                return "iPad 5 (Cellular)"
            case "iPad7,1":                                 return "iPad Pro 12.9 inch 2nd gen (WiFi)"
            case "iPad7,2":                                 return "iPad Pro 12.9 inch 2nd gen (Cellular)"
            case "iPad7,3":                                 return "iPad Pro 10.5 inch (WiFi)"
            case "iPad7,4":                                 return "iPad Pro 10.5 inch (Cellular)"
            case "AppleTV2,1":                              return "Apple TV 2"
            case "AppleTV3,1", "AppleTV3,2":                return "Apple TV 3"
            case "AppleTV5,3":                              return "Apple TV 4"
            case "i386", "x86_64":                          return "Simulator"
            default:                                        return identifier
        }
    }
    
    var descriptions: String {
        let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let shortVersionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let machine = self.modelName
        let systemVersion = UIDevice.current.systemVersion
        let identifierForVendor = UIDevice.current.identifierForVendor
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        let appInfo = "App: \(displayName ?? "")\nVersion: \(shortVersionString ?? "") (\(version ?? ""))\nDevice: \(machine) \(systemVersion)\nUUID: \(String(describing: identifierForVendor)) \nDateime: \(dateString)\n"
        return appInfo;
    }
}



