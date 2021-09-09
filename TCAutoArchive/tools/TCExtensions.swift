//
//  TCExtensions.swift
//  TCAutoArchive
//
//  Created by apple on 2021/9/7.
//

import Cocoa
import Commands
import Alamofire
import SwiftyJSON

typealias numberReturnBlock = (_ prog : Int)->()
typealias stringReturnBlock = (_ desc : String)->()
extension Process {
    
    /// 执行命令
    /// - Parameters:
    ///   - launchPath: 命令路径
    ///   - arguments: 命令参数
    ///   - currentDirectoryPath: 命令执行目录
    ///   - environment: 环境变量
    /// - Returns: 返回执行结果
    static func executable(launchPath:String,
                           arguments:[String],
                           currentDirectoryPath:String? = nil,
                           environment:[String:String]? = nil)->Pipe{
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        if let environment = environment {
            process.environment = environment
        }
        if let currentDirectoryPath = currentDirectoryPath {
            process.currentDirectoryPath = currentDirectoryPath
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.launch()
        return pipe
    }
}
extension String{
    func appPath(_ value:String) -> String {
        if self.hasSuffix("/") {
            return self + value
        }
        return self + "/" + value
    }
}
struct IpaTool {
    
    struct Output {
        var pipe:Pipe
        var readData:String
        init(pipe:Pipe) {
            self.pipe = pipe
            self.readData = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: String.Encoding.utf8) ?? ""
        }
    }
    enum Configuration:String {
        case debug = "Debug"
        case release = "Release"
    }
    
    var workspace:String{
        projectPath.appPath("\(projectName).xcworkspace")
    }
    ///scheme
    var scheme:String
    ///Debug|Release
    var configuration:Configuration
    ///编译产物路径
    var xcarchive:String{
        exportIpaPath.appPath("\(projectName).xcarchive")
    }
    var progressBlock : numberReturnBlock?
    var uploadTypeBlock : stringReturnBlock?
    ///配置文件路径
    var exportOptionsPlist:String
    ///导出ipa包的路径
    var exportIpaPath:String
    ///项目路径
    let projectPath:String
    ///项目名称
    let projectName:String
    ///存放打包目录
    let packageDirectory:String
    ///蒲公英_api_key
    let pgyerKey:String
    
    ///
    /// - Parameters:
    ///   - projectPath: 项目路径
    ///   - configuration: Debug|Release
    ///   - exportOptionsPlist: 配置文件Plist的路径
    ///   - pgyerKey: 上传蒲公英的key
    /// - Throws: 抛出错误
    init(projectPath:String, configuration:Configuration, exportOptionsPlist:String, pgyerKey:String,schemeName:String = "") throws {
        self.projectPath = projectPath
        self.configuration = configuration
        self.exportOptionsPlist = exportOptionsPlist
        self.pgyerKey = pgyerKey
        let manager = FileManager.default
        var allFiles = try manager.contentsOfDirectory(atPath: projectPath)
        projectName = allFiles.first(where: { $0.hasSuffix(".xcodeproj")  })?.components(separatedBy: ".").first ?? ""
        packageDirectory = NSHomeDirectory()
         .appPath("Desktop/\(projectName)_ipa")

        allFiles = try manager.contentsOfDirectory(atPath: projectPath.appPath("\(projectName).xcodeproj/xcshareddata/xcschemes")
        )
        if schemeName.count == 0 {
            scheme = allFiles[0].components(separatedBy: ".").first ?? ""
        }else{
            scheme = schemeName
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        exportIpaPath = packageDirectory.appPath(formatter.string(from: Date()))
    }
}
extension IpaTool{
    /// 执行 xcodebuild clean
    func clean() -> Output{
        let arguments = ["clean",
                                 "-workspace",
                                 workspace,
                                 "-scheme",
                                 scheme,
                                 "-configuration",
                                 configuration.rawValue,
                                 "-quiet",
                                ]
        return Output(pipe: Process.executable(launchPath: "/usr/bin/xcodebuild", arguments: arguments))
    }
    /// 执行 xcodebuild archive
    func archive()->Output{
        let arguments = ["archive",
                         "-workspace",
                         workspace,
                         "-scheme",
                         scheme,
                         "-configuration",
                         configuration.rawValue,
                         "-archivePath",
                         xcarchive,
                         "-quiet",
                        ]
        return Output(pipe: Process.executable(launchPath: "/usr/bin/xcodebuild", arguments: arguments))
    }
    /// 执行 xcodebuild exportArchive
    func exportArchive()->Output{
        let arguments = ["-exportArchive",
                         "-archivePath",
                         xcarchive,
                         "-configuration",
                         configuration.rawValue,
                         "-exportPath",
                         exportIpaPath,
                         "-exportOptionsPlist",
                         exportOptionsPlist,
                         "-quiet",
                        ]
        return Output(pipe: Process.executable(launchPath: "/usr/bin/xcodebuild", arguments: arguments))
    }
    // pod install
    func podInstall()->Output{
       var environment = [String:String]()
       environment["LANG"] = "en_US.UTF-8"
       environment["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin:/Users/gree/.rvm/bin"
       environment["CP_HOME_DIR"] = NSHomeDirectory().appending("/.cocoapods")
       let pipe = Process.executable(launchPath: "/usr/local/bin/pod",
                                   arguments: ["install"],
                                   currentDirectoryPath: projectPath,
                                   environment: environment)
       return Output(pipe: pipe)
    }
    //上传蒲公英
        func upload(){
           
            let ipaPath = exportIpaPath.appPath("\(scheme).ipa")
            
            let upload = AF.upload(multipartFormData: { formdata in
                formdata.append(pgyerKey.data(using: .utf8)!, withName: "_api_key")
                formdata.append(URL(fileURLWithPath: ipaPath), withName: "file")
            }, to: URL(string: "https://www.pgyer.com/apiv2/app/upload")!)
            
            var isExit = true
            let queue = DispatchQueue(label: "queue")
            upload.uploadProgress(queue: queue) { progress in
                let p = Int((Double(progress.completedUnitCount) / Double(progress.totalUnitCount)) * 100)
                if progressBlock != nil{
                    progressBlock!(p)
                }
            }
            upload.responseData(queue:queue) { dataResponse in
                switch dataResponse.result {
                case .success(let data):
                    let json = try? JSON(data: data)
                    guard json != nil else {
                        return
                    }
                    let code = json!["code"]
                    if code == 0 {
                        if (uploadTypeBlock != nil) {
                            uploadTypeBlock!("上传成功")
                        }
                    }else{
                        if (uploadTypeBlock != nil) {
                            uploadTypeBlock!(String(describing: json!["message"]))
                        }
                    }
                    
                case .failure( _):
                    if (self.uploadTypeBlock != nil) {
                        self.uploadTypeBlock!("上传失败")
                    }
                }
                isExit = false
            }
            //使用循环换保证命令行程序,不会死掉
            while isExit {
                Thread.sleep(forTimeInterval: 1)
            }
        }

}
