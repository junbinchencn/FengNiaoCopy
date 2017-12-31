//
//  main.swift
//  FengNiaoCopy
//
//  Created by junbin on 2017/12/5.
//
//

import Foundation
import CommandLineKit
import Rainbow
import PathKit
import FengNiaoKitCopy


let appVersion = "0.4.1"

// 修改自 https://github.com/jatoben/CommandLine
let cli = CommandLineKit.CommandLine()
cli.formatOutput = { s,type in
    var str : String
    switch(type){
    case .error:
        str = s.red.bold
    case .optionFlag:
        str = s.green.underline
    default: str = s
    }
    return cli.defaultFormat(s: str, type: type)
}


let projectPathOption = StringOption(shortFlag: "p", longFlag: "project", helpMessage: "Root path of your Xcode project. Default is current folder.")

let isForceOption = BoolOption(longFlag: "force", helpMessage: "Delete the found unused files without asking.")

let excludePathOption = MultiStringOption(shortFlag: "e", longFlag: "exclude", helpMessage: "Exclude paths from search")

let resourceExtOption = MultiStringOption(shortFlag: "r", longFlag: "resource-extensions", helpMessage: "Resource file extensions need to be searched. Default is 'imageset jpg png gif'")

let fileExtOption = MultiStringOption(
    shortFlag: "f", longFlag: "file-extensions",
    helpMessage: "In which types of files we should search for resource usage. Default is 'm mm swift xib storyboard'")

let skipProjRefereceCleanOption = BoolOption(
    longFlag: "skip-proj-reference",
    helpMessage: "Skip the Project file (.pbxproj) reference cleaning. By skipping it, the project file will be left untouched. You may want to skip ths step if you are trying to build multiple projects with dependency and keep .pbxproj unchanged while compiling."
)

let versionOption = BoolOption(longFlag: "version", helpMessage: "Print version.")


let helpOption = BoolOption(shortFlag: "h", longFlag: "help",
                            helpMessage: "Print this help message.")

cli.addOptions(projectPathOption,isForceOption,excludePathOption,resourceExtOption,fileExtOption,skipProjRefereceCleanOption,versionOption,helpOption)

do{
    try cli.parse()
}catch{
    cli.printUsage(error)
    exit(EX_USAGE)
}

// 有未知参数
if !cli.unparsedArguments.isEmpty{
    print("Unknow arguments: \(cli.unparsedArguments)".red)
    cli.printUsage()
    exit(EX_OK)
}

// 打印帮助
if helpOption.value{
    cli.printUsage()
    exit(EX_OK)
}

// 打印版本
if versionOption.value{
    print(appVersion)
    exit(EX_OK)
}

// ?? 操作符，先对可选值进行拆包，如果不为 nil 返回操作符前面的值，如果为空返回后者
let projectPath = projectPathOption.value ?? "."
let isForce = isForceOption.value
let excludePaths = excludePathOption.value ?? []
let resourceExtentions = resourceExtOption.value ?? ["imageset","jpg","png","gif"]
let fileExtensions = fileExtOption.value ?? ["m","mm","swift","xib","storyboard","plist"]



let fengNiao = FengNiaoCopy(projectPath: projectPath,
                        excludedPaths: excludePaths,
                        resourceExtensions: resourceExtentions,
                        searchInFileExtensions: fileExtensions)
// swift 异常处理
let unusedFiles: [FileInfo]
do {
    print("Searching unused file. This may take a while...")
    unusedFiles = try fengNiao.unusedFiles()
} catch {
    // 可以自动捕获异常 error 变量
    // as!使用场合  向下转型（Downcasting）时使用。由于是强制类型转换，如果转换失败会报 runtime 运行错误。
    // as? 和 as! 操作符的转换规则完全一样。但 as? 如果转换不成功的时候便会返回一个 nil 对象。成功的话返回可选类型值（optional），需要我们拆包使用。
    // 由于 as? 在转换失败的时候也不会出现错误，所以对于如果能确保100%会成功的转换则可使用 as!，否则使用 as?
    guard let e = error as? FengNiaoError else {
        print("Unknown Error: \(error)".red.bold)
        exit(EX_USAGE)
    }
    switch e {
    case .noResourceExtension:
        print("You need to specify some resource extensions as search target. Use --resource-extensions to specify.".red.bold)
    case .noFileExtension:
        print("You need to specify some file extensions to search in. Use --file-extensions to specify.".red.bold)
    }
    exit(EX_USAGE)
}

if unusedFiles.isEmpty {
    print("😎 Hu, you have no unused resources in path: \(Path(projectPath).absolute()).".green.bold)
    exit(EX_OK)
}


if !isForce {
    // 列出未使用的资源列表
    var result = promptResult(files: unusedFiles)
    while result == .list {
        for file in unusedFiles {
            print("\(file.readableSize) \(file.path.string)")
        }
        result = promptResult(files: unusedFiles)
    }
    
    switch result {
    case .list:
        fatalError()
    case .delete:
        break
    case .ignore:
        print("Ignored. Nothing to do, bye!".green.bold)
        exit(EX_OK)
    }
}

//删除资源文件
print("Deleting unused files...⚙".bold)

let (deleted, failed) = FengNiaoCopy.delete(unusedFiles)
// guard语句类似于if语句，是否执行语句也是基于Boolean表达式，使用guard关键字需要条件为true才会让guard后面的语句执行
// guard语句一直需要有一个else语句块，else语句块是条件不满足时需要执行的代码
// guard 之后的 failed.isEmpty 判断条件为 false 时，执行 else 分支代码
guard failed.isEmpty else {
    print("\(unusedFiles.count - failed.count) unused files are deleted. But we encountered some error while deleting these \(failed.count) files:".yellow.bold)
    for (fileInfo, err) in failed {
        print("\(fileInfo.path.string) - \(err.localizedDescription)")
    }
    exit(EX_USAGE)
}


print("\(unusedFiles.count) unused files are deleted.".green.bold)
// 删除 project.pbxproj 里面的引用
if !skipProjRefereceCleanOption.value {
    if let children = try? Path(projectPath).absolute().children(){
        print("Now Deleting unused Reference in project.pbxproj...⚙".bold)
        for path in children {
            if path.lastComponent.hasSuffix("xcodeproj"){
                let pbxproj = path + "project.pbxproj"
                FengNiaoCopy.deleteReference(projectFilePath: pbxproj, deletedFiles: deleted)
            }
        }
        print("Unused Reference deleted successfully.".green.bold)
    }
}




