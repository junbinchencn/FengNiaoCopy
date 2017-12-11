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


if !cli.unparsedArguments.isEmpty{
    print("Unknow arguments: \(cli.unparsedArguments)".red)
    cli.printUsage()
    exit(EX_OK)
}

if helpOption.value{
    cli.printUsage()
    exit(EX_OK)
}

if versionOption.value{
    print(appVersion)
    exit(EX_OK)
}


let projectPath = projectPathOption.value ?? "."
let isForce = isForceOption.value
let excludePaths = excludePathOption.value ?? []
let resourceExtentions = resourceExtOption.value ?? ["imageset","jpg","png","gif"]
let fileExtensions = fileExtOption.value ?? ["m","mm","swift","xib","storyboard","plist"]






