//
//  ExtensionsCopy.swift
//  FengNiaoCopy
//
//  Created by junbin on 2017/12/10.
//
//

import Foundation
import PathKit

extension String{
    var fullRange:NSRange{
        let nsstring = NSString(string: self)
        return NSMakeRange(0, nsstring.length)
    }
    
    func plainFileName(extensions:[String]) -> String{
        let p = Path(self)
        var result : String!
        for ext in extensions {
            if hasSuffix(".\(ext)"){
                result = p.lastComponentWithoutExtension
                break
            }
        }
        
        if result == nil {
            result = p.lastComponent
        }
        
        if result.hasSuffix("@2x") || result.hasSuffix("@3x") {
            let endIndex = result.index(result.endIndex, offsetBy: -3)
            result = result.substring(to: endIndex);
        }
        return result
    }

}
