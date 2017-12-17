//
//  ExtensionFindProcessCopy.swift
//  FengNiaoCopy
//
//  Created by junbin on 2017/12/12.
//
//

import Foundation
import PathKit

// 系统 find 命令处理工具
class ExtensionFindProcess : NSObject {
    let p : Process
    init?(path:Path,extensions: [String],excluded:[Path]){
        // find 命令
        p = Process()
        p.launchPath = "/usr/bin/find"
        
        guard !extensions.isEmpty else {
            return nil
        }
        // 参数拼接
        var args = [String]()
        args.append(path.string)
        
        // 搜索文件的后缀
        // 快速枚举某个数组的 EnumerateGenerator，它的元素是同时包含了元素下标索引以及元素本身的多元组
        for(i,ext) in extensions.enumerated(){
            if i == 0 {
                args.append("(")
            } else {
                args.append("-or")
            }
            
            args.append("-name")
            args.append("*.\(ext)")
            
            if i == extensions.count - 1 {
                args.append(")")
            }
        }
        // 排除路径
        for excludedPath in excluded {
            args.append("-not")
            args.append("-path")
            // 文件路径判断
            let filePath = path + excludedPath
            guard filePath.exists else{
                continue
            }
            // 文件夹处理
            if filePath.isDirectory {
                args.append("\(filePath.string)/*)")
            }else{
                args.append(filePath.string)
            }
        
        }
        p.arguments = args
    }
    
    
    convenience init(path: String,extensions: [String], excluded: [String]) {
        self.init(path: path, extensions: extensions, excluded: excluded)
    }
    // 执行结果处理，返回资源文件路径的 Set 集合
    func execute() -> Set<String> {
        let pipe = Pipe()
        p.standardOutput = pipe
        
        let fileHandler = pipe.fileHandleForReading
        p.launch()
        
        let data = fileHandler.readDataToEndOfFile()
        
        if let string = String(data:data,encoding:.utf8){
            return Set(string.components(separatedBy: "\n").dropLast())
        }else{
            return []
        }
        
    }
    
    
}
