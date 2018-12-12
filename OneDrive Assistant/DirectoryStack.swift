//
//  DirectoryStack.swift
//  OneDrive Assistant
//
//  Created by Thomas Lagrange on 12/11/18.
//  Copyright © 2018 Thomas Lagrange. All rights reserved.
//

import Cocoa

class DirectoryStack: NSObject {
    fileprivate var array: [URL] = []
    fileprivate var size: Int
    
    override init() {
        size = 0
    }
    
    func isEmpty() -> Bool {
        return array.isEmpty
    }
    
    func length(of: DirectoryStack) -> Int {
        return array.count;
    }
    
    func push(_ element: URL) {
        array.append(element)
    }
    
    func pop() -> URL? {
        return array.popLast()
    }
    
    func peek() -> URL? {
        return array.last
    }
}
