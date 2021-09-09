//
//  TCMainViewCtr.swift
//  TCAutoArchive
//
//  Created by apple on 2021/9/7.
//

import Cocoa
import Commands
import SnapKit

class TCMainViewCtr: NSViewController , NSOpenSavePanelDelegate  {

    @IBOutlet weak var schemeTF: NSTextField!
    @IBOutlet weak var objPathLab: NSTextField!
    var fileUrl : String?
    var isChoseRelease = true
    var isChoseBitCode = true
    var archiveType = 1//adhoc是1
    var projectName : String?
    var isPodInstall = false
    var isUploadPGY = false
    
    @IBOutlet weak var uploadBtn: NSButton!
    @IBOutlet weak var p_appkeyTF: NSTextField!
    @IBOutlet weak var teamIdTF: NSTextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        let def = UserDefaults.standard
        let proj_path = def.object(forKey: "proj_path") as? String
        if (proj_path?.count ?? 0) > 0 {
            self.fileUrl = proj_path
            self.objPathLab.stringValue = self.fileUrl!
        }
        let teamid = def.object(forKey: "teamid") as? String
        if (teamid ?? "").count > 0 {
            self.teamIdTF.stringValue = teamid ?? ""
        }
        let apikey = def.object(forKey: "pgy_api_key") as? String
        if (apikey ?? "").count > 0 {
            self.p_appkeyTF.stringValue = apikey ?? ""
        }
    }
    
    @IBAction func choseObjClick(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.prompt = "打开"// prompt : 修改默认打开按钮的文字
        panel.message = "不要随便选择文件"
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
//        panel.canCreateDirectories = true
        // 设置默认打开的文件路径
        let pathUrl = URL(string: "\(NSHomeDirectory())/Desktop")
        panel.directoryURL = pathUrl
        panel.delegate = self
        // 显示panel
        panel.begin { (response) in
            if response == NSApplication.ModalResponse.OK {
                guard panel.urls.count > 0 else {
                    self.alertMethod(msg: "请选择一个文件夹")
                    return
                }
                let def = UserDefaults.standard
                let url = panel.urls.first
                self.fileUrl = url!.absoluteString.replacingOccurrences(of: "file://", with: "")
                def.setValue(self.fileUrl, forKey: "proj_path")
                self.objPathLab.stringValue = self.fileUrl!
            }
        }
    }
    
    @IBAction func segClick(_ sender: NSSegmentedControl) {
        if sender.indexOfSelectedItem == 0 {
            isChoseRelease = true
        }else{
            isChoseRelease = false
        }
    }
    
    @IBAction func bitcodeBtnClick(_ sender: NSButton) {
        if sender.state.rawValue == 1{
            isChoseBitCode = true
        }else{
            isChoseBitCode = false
        }
    }
    
    @IBAction func podInstall(_ sender: NSButton) {
        if sender.state.rawValue == 0 {
            isPodInstall = false
        }else{
            isPodInstall = true
        }
    }
    @IBAction func uploadClick(_ sender: NSButton) {
        guard archiveType != 2 else {
            alertMethod(msg: "App Store包无法上传到蒲公英")
            return
        }
        if sender.state.rawValue == 0 {
            isUploadPGY = false
            p_appkeyTF.isEnabled = false
        }else{
            isUploadPGY = true
            p_appkeyTF.isEnabled = true
        }
    }
    
    @IBAction func archiveTypeClick(_ sender: NSSegmentedControl) {
        archiveType = sender.indexOfSelectedItem + 1
        if archiveType == 2 {
            uploadBtn.state = NSControl.StateValue(rawValue: 0)
            p_appkeyTF.stringValue = ""
        }
    }
    @IBAction func startClick(_ sender: Any) {
        guard self.teamIdTF.stringValue.count > 0 else {
            alertMethod(msg: "teamId不能为空")
            return
        }
        guard (self.fileUrl ?? "").count > 0 else {
            alertMethod(msg: "请选择项目")
            return
        }
        if isUploadPGY {
            guard self.p_appkeyTF.stringValue.count > 0 else {
                self.alertMethod(msg: "蒲公英appkey不能为空")
                return
            }
            let def = UserDefaults.standard
            def.setValue(self.p_appkeyTF.stringValue, forKey: "pgy_api_key")
        }
        let def = UserDefaults.standard
        def.setValue(self.teamIdTF.stringValue, forKey: "teamid")
        let arr = self.fileUrl!.components(separatedBy: "/")
        guard arr.count > 0 else {
            alertMethod(msg: "路径错误")
            return
        }
        let projName = arr[arr.count -  2]
        projectName = projName+"_ipa"
        startArchive(path: self.fileUrl!)
    }
    func startArchive(path:String){
        let plist_path = "\(NSHomeDirectory())/Desktop/\(projectName!)"
        let isGoOn = generateExportList(path: plist_path)
        guard isGoOn else {
            return
        }
        do{
            var ipaTool = try IpaTool(projectPath: path,
                                      configuration: isChoseRelease ? .release :.debug,
                                  exportOptionsPlist: plist_path+"/ExportOptions.plist",
                                  pgyerKey: self.isUploadPGY ? self.p_appkeyTF.stringValue:"",
                                  schemeName: self.schemeTF.stringValue)
            let indicat = TCIndicatorView(nibName: "TCIndicatorView", bundle: nil)
            self.view.addSubview(indicat.view)
            indicat.view.snp.makeConstraints { (make) in
                make.width.equalTo(150)
                make.height.equalTo(150)
                make.center.equalTo(self.view)
            }
            let queue = OperationQueue()
            queue.addOperation {
                if self.isPodInstall {
                    OperationQueue.main.addOperation{
                        indicat.infoLab.stringValue = "执行pod install操作"
                    }
                    let out = ipaTool.podInstall()
                    let isCompleted = out.readData.contains("installation complete")
                    if !isCompleted {
                        self.alertMethod(msg: "pod install 失败：\(out.readData)")
                        return
                    }
                    OperationQueue.main.addOperation{
                        indicat.infoLab.stringValue = "pod install 完成"
                    }
                }
                OperationQueue.main.addOperation{
                    indicat.infoLab.stringValue = "执行clean操作"
                }
                var output = ipaTool.clean()
                if output.readData.count > 0 {
                    self.alertMethod(msg: "执行失败clean error = \(output.readData)")
                }
                OperationQueue.main.addOperation {
                    indicat.infoLab.stringValue = "打包中"
                }
                output = ipaTool.archive()
                if !FileManager.default.fileExists(atPath: ipaTool.xcarchive) {
                    self.alertMethod(msg: "执行失败archive error = \(output.readData)")
                }
                OperationQueue.main.addOperation {
                    indicat.infoLab.stringValue = "开始导出"
                }
                output = ipaTool.exportArchive()
                
                let ipa_path = ipaTool.exportIpaPath.appPath("\(ipaTool.scheme).ipa")
                if !FileManager.default.fileExists(atPath: ipa_path) {
                    self.alertMethod(msg:"执行失败exportArchive error =\(output.readData)")
                }
                OperationQueue.main.addOperation {
                    indicat.infoLab.stringValue = "导出ipa成功"
                    self.succeedNotify()
                }
                
                if self.isUploadPGY{
                    ipaTool.progressBlock = {(prog) in
                        OperationQueue.main.addOperation{
                            indicat.infoLab.stringValue = "上传进度：\(prog)"
                        }
                    }
                    ipaTool.uploadTypeBlock = {(desc) in
                        OperationQueue.main.addOperation{
                            indicat.infoLab.stringValue = desc
                            DispatchQueue.main.asyncAfter(deadline: .now()+1, execute:{
                                indicat.view.removeFromSuperview()
                            })
                        }
                    }
                    ipaTool.upload()
                }else{
                    DispatchQueue.main.asyncAfter(deadline: .now()+1, execute:{
                        indicat.view.removeFromSuperview()
                    })
                }
            }
        }catch{
            print(error)
        }
    }
    func succeedNotify(){
        let notification = NSUserNotification()
        notification.title = "导出ipa成功"
        notification.informativeText = "文件已保存在项目名_ipa文件中"
        notification.deliveryDate = Date()
        let center = NSUserNotificationCenter.default
        center.delegate = self
        center.deliver(notification)
    }
    func alertMethod(msg : String){
        OperationQueue.main.addOperation {
            let alert:NSAlert = NSAlert()
            alert.messageText = msg
            alert.addButton(withTitle: "好")
            alert.alertStyle = .critical
            alert.runModal()
        }
    }
    func generateExportList(path:String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let bitcode = isChoseBitCode ? "<true/>" : "<false/>"
        let archive_type_str = archiveType==1 ? "ad-hoc" : archiveType==2 ? "app-store" : archiveType==3 ? "enterprise" : "development"
        let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n<key>compileBitcode</key>\n\(bitcode)\n<key>destination</key>\n<string>export</string>\n<key>method</key>\n<string>\(archive_type_str)</string>\n<key>signingStyle</key>\n<string>automatic</string>\n<key>stripSwiftSymbols</key>\n<true/>\n<key>teamID</key>\n<string>\(self.teamIdTF.stringValue)</string>\n<key>thinning</key>\n<string>&lt;none&gt;</string>\n</dict>\n</plist>"
        //42V8X776Y7
        let result = Commands.Task.run("mkdir \(path)")
        var isGoOn = true
        switch result {
        case .Success( _,  _):
            try?plist.write(toFile: path+"/ExportOptions.plist", atomically: true, encoding: .utf8)
        case .Failure(let request, let response):
            alertMethod(msg: "command: \(request.absoluteCommand), failure output: \(response.errorOutput)")
            isGoOn = false
        }
        return isGoOn
    }
    
}
extension TCMainViewCtr: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool  {
        return true
    }
}
