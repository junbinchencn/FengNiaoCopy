//
//  FileSearchRuleCopy.swift
//  FengNiaoCopy
//
//  Created by junbin on 2017/12/10.
//
//

import Foundation

// 定义协议
protocol FileSearchRule {
    func search(in content : String) -> Set<String>
}

// 协议继承
protocol RegPatternSearchRule : FileSearchRule {
    var extensions:[String] { get }
    var patterns:[String] { get }
}

// 拓展协议
extension RegPatternSearchRule{
    // 查找文件名
    func search(in content :String) -> Set<String>{
        let nsstring = NSString(string:content)
        var result = Set<String>()
        for pattern in patterns {
            let reg = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = reg.matches(in: content, options: [], range: content.fullRange)
            for checkingResult in matches {
                let extracted = nsstring.substring(with: checkingResult.rangeAt(1))
                result.insert(extracted.plainFileName(extensions: extensions))
            }
        }
        return result;
    }
}

// 用于普通文件的字符串搜索
struct PlainImageSearchRule : RegPatternSearchRule {
    let extensions: [String]
    var patterns: [String] {
        if extensions.isEmpty {
            return []
        }
        
        let joinedExt = extensions.joined(separator: "|")
        return ["\"(.+?)\\.(\(joinedExt))\""]
    }
}

// 用于 ObjC 类型文件的字符串搜索
struct ObjCImageSearchRule : RegPatternSearchRule {
    let extensions: [String]
    // 匹配任意字符串 @""  ""
    let patterns = ["@\"(.*?)\"", "\"(.*?)\""]
}

// 用于 Swift 类型文件的字符串搜索
struct SwiftImageSearchRule : RegPatternSearchRule {
    let  extensions: [String]
    // 匹配任意字符串 ""
    let patterns = ["\"(.*?)\""]
}

// 用于 xib storyboard 的字符串搜索
struct XibImageSearchRule : RegPatternSearchRule {
    let extensions =  [String]()
    // .xib 字符串 image=""
    let patterns = ["image name=\"(.*?)\"", "image=\"(.*?)\"", "value=\"(.*?)\""]
}

// 用于 plist 的字符串搜索
struct PlistImageSearchRule :RegPatternSearchRule {
    let extensions =  [String]()
    let patterns = ["<key>UIApplicationShortcutItemIconFile</key>[^<]*<string>(.*?)</string>"]
}

