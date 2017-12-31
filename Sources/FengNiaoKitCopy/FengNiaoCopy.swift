import Foundation
import PathKit
import Rainbow


enum FileType {
    case swift
    case objc
    case xib
    case plist
    
    init?(ext: String){
        switch ext {
        case "swift": self = .swift
        case "m", "mm": self = .objc
        case "xib", "storyboard": self = .xib
        case "plist": self = .plist
        default: return nil
        }
    }
    
    func searchRules(extensions: [String]) -> [FileSearchRule] {
        switch self {
        case .swift: return [SwiftImageSearchRule(extensions: extensions)]
        case .objc: return [ObjCImageSearchRule(extensions: extensions)]
        case .plist: return [PlistImageSearchRule(extensions: extensions)]
        case .xib: return [XibImageSearchRule()]
        }
    }
}

//文件信息
public struct FileInfo{
    public let path: Path
    public let size: Int
    public let fileName: String
    
    init(path: String){
        self.path = Path(path)
        self.size = self.path.size
        self.fileName = self.path.lastComponent
    }
    
    public var readableSize: String {
        return size.fn_readableSize
    }
    
}

extension Path {
    // 计算文件夹或者文件的 size
    var size: Int {
        if isDirectory {
            let childrenPaths = try? children()
            return (childrenPaths ?? []).reduce(0) { $0 + $1.size }
        } else {
            // Skip hidden files
            if lastComponent.hasPrefix(".") { return 0 }
            let attr = try? FileManager.default.attributesOfItem(atPath: absolute().string)
            if let num = attr?[.size] as? NSNumber {
                return num.intValue
            } else {
                return 0
            }
        }
    }
}

public enum FengNiaoError: Error {
    case noResourceExtension
    case noFileExtension
}



let digitalRex = try! NSRegularExpression(pattern: "(\\d+)",options: .caseInsensitive)
extension String {
    // 在做图片的数组动画需求的时候，可能存这种情况
    // 在代码里面写 "image%02d",但是图片资源名称是类似 "image01","image02","image03"
    func similarPatternWithNumberIndex(other: String) -> Bool {
        let matches = digitalRex.matches(in: other, options: [], range: other.fullRange)
        guard matches.count >= 1 else { return false }
        let lastMatch = matches.last!
        let digitalRange = lastMatch.rangeAt(1)
        var prefix: String?
        var suffix: String?
        // 取出前缀
        let digitalLocation = digitalRange.location
        if digitalLocation != 0 {
            let index = other.index(other.startIndex, offsetBy: digitalLocation)
            prefix = other.substring(to: index)
        }
        // 取出后缀
        let digitalMaxRange = NSMaxRange(digitalRange)
        if digitalMaxRange < other.utf16.count {
            let index = other.index(other.startIndex, offsetBy: digitalMaxRange)
            suffix = other.substring(from: index)
        }
        
        switch (prefix,suffix) {
        case (nil, nil):
            return false
        case (let p?, let s?):
            return hasPrefix(p) && hasSuffix(s)
        case (let p?, nil):
            return hasPrefix(p)
        case (nil, let s?):
            return hasSuffix(s)
        }
    }
}



public struct FengNiaoCopy{
    let projectPath: Path
    let excludedPaths: [Path]
    let resourceExtensions: [String]
    let searchInFileExtensions: [String]
    
    let regularDirExtensions = ["imageset", "launchimage", "appiconset", "bundle"]
    var nonDirExtensions: [String] {
        return resourceExtensions.filter { !regularDirExtensions.contains($0) }
    }
    // 初始化方法
    public init(projectPath: String, excludedPaths: [String], resourceExtensions: [String], searchInFileExtensions: [String]) {
        let path = Path(projectPath).absolute()
        self.projectPath = path
        self.excludedPaths = excludedPaths.map { path + Path($0) }
        self.resourceExtensions = resourceExtensions
        self.searchInFileExtensions = searchInFileExtensions
    }
    
    // 返回所有合适的资源文件,key 是资源文件名字 value是文件路径
    func allResourceFiles() -> [String: Set<String>] {
        let find = ExtensionFindProcess(path: projectPath, extensions: resourceExtensions, excluded: excludedPaths)
        guard let result = find?.execute() else {
            print("Resource finding failed.".red)
            return [:]
        }
        
        var files = [String : Set<String>]()
        fileLoop: for file in result {
            //跳过 bundle 里面的资源文件
            let dirPaths = regularDirExtensions.map{".\($0)/"}
            for dir in dirPaths where file.contains(dir) {
                continue fileLoop
            }
            //跳过一些有奇葩文件夹命名方式的文件，用非文件夹后缀的名字来命名文件夹，比如用 myfolder.png 来命名文件夹
            let filePath = Path(file)
            if let ext = filePath.extension, filePath.isDirectory && nonDirExtensions.contains(ext) {
                continue
            }
            
            let key = file.plainFileName(extensions: resourceExtensions)
            if let existing = files[key] {
                // Set 合并
                files [key] = existing.union([file])
            } else {
                files[key] = [file]
            }
        }
        
        return files
        
    }
    
    // 所有的资源字符串
    func allUsedStringNames() -> Set<String> {
        return usedStringNames(at: projectPath)
    }
    
    func usedStringNames(at path: Path) -> Set<String> {
        guard let subPaths = try? path.children() else {
            print("Failed to get contents in path: \(path)".red)
            return []
        }
        var result = [String]()
        for subPath in subPaths {
            // 略过隐藏文件夹
            if subPath.lastComponent.hasPrefix(".") {
                continue
            }
            
            // 略过用户想忽略的文件夹
            if excludedPaths.contains(subPath) {
                continue
            }
            
            // 对文件夹进行递归查找
            if subPath.isDirectory {
                result.append(contentsOf: usedStringNames(at: subPath))
            } else {
                // 内容搜索
              let fileExt = subPath.extension ?? ""
                guard searchInFileExtensions.contains(fileExt) else {
                    continue
                }
                
                let fileType = FileType(ext: fileExt)
                let searchRules = fileType?.searchRules(extensions: resourceExtensions) ?? [PlainImageSearchRule(extensions: resourceExtensions)]
                let content = (try? subPath.read()) ?? ""
                
                result.append(contentsOf: searchRules.flatMap{$0.search(in: content)})
            }
        }
        return Set(result)
    }
    // 查找未使用的资源文件
    static func filterUnused(from all: [String: Set<String>], used: Set<String>) -> Set<String> {
        let unusedPairs = all.filter { key,_ in
            return !used.contains(key) &&
                   !used.contains{$0.similarPatternWithNumberIndex(other: key) }
        }
        return Set( unusedPairs.flatMap{ $0.value })
    }
    
    // 查找未被使用的图片资源
    public func unusedFiles() throws -> [FileInfo] {
        // 参数判断
        guard !resourceExtensions.isEmpty else {
            throw FengNiaoError.noResourceExtension
        }
        
        guard !searchInFileExtensions.isEmpty else {
            throw FengNiaoError.noFileExtension
        }
        
        let allResources = allResourceFiles()
        let usedNames = allUsedStringNames()
        
        return FengNiaoCopy.filterUnused(from: allResources, used: usedNames).map( FileInfo.init )
    }
    // 删除文件，保存删除成功文件的列表和删除失败文件的列表
    static public func delete(_ unusedFiles: [FileInfo]) -> (deleted: [FileInfo], failed :[(FileInfo, Error)]) {
        var deleted = [FileInfo]()
        var failed = [(FileInfo,Error)]()
        for file in unusedFiles {
            do {
                try file.path.delete()
                deleted.append(file)
            } catch {
                failed.append((file, error))
            }
        }
        return (deleted, failed)
    }
    // 删除 project.pbxproj 里面的资源引用
    static public func deleteReference(projectFilePath: Path, deletedFiles: [FileInfo]) {
        if let content: String = try? projectFilePath.read() {
            let lines = content.components(separatedBy: .newlines)
            var results:[String] = []
            // 逐行读取 project.pbxproj 文件，
            // 若是 line 包含 image reference 则 line 不再写回 project.pbxproj 文件
            for line in lines {
                var containImage = true
                outerLoop: for file in deletedFiles {
                    if line.contains(file.fileName) {
                        containImage = false
                        continue outerLoop
                    }
                }
                if containImage {
                    results.append(line)
                }
            }
            
            let resultString = results.joined(separator: "\n")
            
            do {
                try projectFilePath.write(resultString)
            } catch {
                print(error)
            }
            
        }
        
    }
}



