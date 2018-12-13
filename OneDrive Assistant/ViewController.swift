/**
 * Copyright (c) 2018 Thomas Lagrange
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Cocoa

public enum FileExistence: Equatable {
    case none
    case file
    case directory
}

public func ==(lhs: FileExistence, rhs: FileExistence) -> Bool {
    
    switch (lhs, rhs) {
    case (.none, .none),
         (.file, .file),
         (.directory, .directory):
        return true
        
    default: return false
    }
}

class ViewController: NSViewController {
    
    
    // MARK: - Outlets
    @IBOutlet var saveButton: NSButton!
    @IBOutlet var startButton: NSButton!
    @IBOutlet var textView: NSTextView!
    @IBOutlet var progressBar: NSProgressIndicator!
    
    // MARK: - Properties
    var fileStack = DirectoryStack()
    var fileCount = 0
    var folderCount = 0
    var totalItems = 0
    
    // TO-DO: - Fix this assignment here to not have a default
    var currentDirectory = URL(fileURLWithPath: "/var/tmp")
    
    var selectedFolder: URL? {
        didSet {
            if let selectedFolder = selectedFolder {
                print("Selected Folder = " + selectedFolder.absoluteString)
            } else {
                print("no directory selected")
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.string = "Welcome! Please select the root folder for your One Drive "
    }
    
}

// MARK: - Output Information to User
extension ViewController {
    
    func output(message: String) {
        self.textView.string.append(message)
        self.textView.string.append("\n")
    }
}

// MARK: - Depth First Search over Contents

extension ViewController {
    
    func fixContents(at root: URL) -> Void {
        // Load the Stack
        depthFirstTraversal(through: root)
        
//        self.totalItems = self.folderCount + self.fileCount
//
//        self.progressBar.minValue = Double(0)
//        self.progressBar.maxValue = Double(self.totalItems)
//        self.progressBar.startAnimation(self.progressBar)
        
        // As long as we have something in the stack, lets' rename some stuff
        while !self.fileStack.isEmpty() {
            self.currentDirectory = self.fileStack.pop()!
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.currentDirectory, includingPropertiesForKeys: [], options: [])
                var index = 0
                for file in files {
                    // Rename the content of the folder
                    checkName(of: file, at: index)
//                    self.progressBar.increment(by: Double(1))
                    index += 1
                }
            } catch {
                output(message: "Unknown error encountered while retrieving files in \(self.currentDirectory.absoluteString.dropFirst(7)), skipping this directory")
            }
        }
        output(message: "Finished working on \(self.folderCount) folder(s) and \(self.fileCount) file(s).")
    }
    
    // Build a stack that will allows us to go through each "level" of the directory backwards
    func depthFirstTraversal(through folder: URL) {
        var isLeaf = true
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [], options: [])
            for content in contents {
                // Push any directories in folder
                if FileManager.default.existence(atUrl: content) == FileExistence.directory {
                    self.fileStack.push(content)
                    depthFirstTraversal(through: content)
                    isLeaf = false
                    self.folderCount += 1
                } else {
                    self.fileCount += 1
                }
            }
        } catch {
            print("Error during enumeration")
        }
        if isLeaf {
            return
        }
        // Push any directories in folder
        // Once done, DFS through those folders
    }
}

// MARK: - Check & Fix Path Name

extension ViewController {
    
    /*
    Filenames will be checked for things that will prevent upload to OneDrive.
     This includes:
        -some special characters
        -some forbidden filenames
        -whitespaces at the beginning or end of the filename (excluding the extension).
            -This is not in the documentation but was discovered in testing
     See doc: https://support.office.com/en-us/article/invalid-file-names-and-file-types-in-onedrive-onedrive-for-business-and-sharepoint-64883a5d-228e-48f5-b3d2-eb39e07630fa
    */

    //Supply the URL of a file to check
    //Supply the index which will be used to avoid duplicate naming (TO-DO: Better method for avoiding duplicates)
    func checkName(of oldFile: URL, at index: Int) {
        let isDirectory = FileManager.default.existence(atUrl: oldFile) == FileExistence.directory
        let oldFileName = oldFile.lastPathComponent
        var oldFileNameWithoutExtension: String
        var newFileName: String
        var needsRenaming = false
        var newFileNameWithoutExtension: String
 
        // We are not concerned with blocking or fixing extensions (for now...)
        // Because of this, we want to have access to the filename without it's extension (if it has one)
        let fileExtension = oldFile.pathExtension
        if fileExtension.isEmpty {
            // No file extension, just return the name of the file
            oldFileNameWithoutExtension = oldFileName
        } else {
            // There is a file extension, let's remove it!
            oldFileNameWithoutExtension = oldFile.deletingPathExtension().lastPathComponent
        }
        
        // If the file is .DS_Store, ignore it
        if oldFileName == ".DS_Store" {
            return
        }
        
        // If the file is a forbidden name, fix it and return
        switch oldFileName {
        case ".lock","CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9",
             "LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9":
            if isDirectory {
                newFileName = "FOLDER\(index)"
            } else {
                newFileName = "FILE\(index)"
            }
            guard rename(file: oldFile, to: newFileName, isDirectory: isDirectory) != nil else { return }
            return
        case "desktop.ini":
            newFileName = "desktop-ini"
            guard rename(file: oldFile, to: newFileName, isDirectory: isDirectory) != nil else { return }
            return
        default:
            break
        }
        
        // If the file is called 'forms' and is at the directory root, rename it to 'formsFile' and return
        if oldFileName == "forms" && !isDirectory && self.currentDirectory == self.selectedFolder {
            guard rename(file: oldFile, to: "formsFile", isDirectory: isDirectory) != nil else { return }
            return
        }
        
        // TO-DO: - Make this more Swifty
        // Trim the filename (without extension) to be safe
        let oldFileNameWithoutExtensionTrimmed = oldFileNameWithoutExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if oldFileNameWithoutExtensionTrimmed != oldFileNameWithoutExtension {
            // Looks like we trimmed something. We should mark this file to be renamed.
            needsRenaming = true
        }
        
        // If the file starts with '~$', replace the occurence with '-$' and continue
        if oldFileNameWithoutExtension.prefix(2) == "~$" {
            oldFileNameWithoutExtension = "-$" + oldFileNameWithoutExtension.dropFirst(2)
            needsRenaming = true
        }
        
        // If the file contains '_vti_' in the filename, replace the occurence with '-vti-' and continue
        if oldFileNameWithoutExtension.contains("_vti_") {
            oldFileNameWithoutExtension = oldFileNameWithoutExtension.replacingOccurrences(of: "_vti_", with: "-vti-")
            needsRenaming = true
        }
        
        // If we're still here we need to check for illegal characters
        // Illegal characters: ~ " # % & : * < > ? / \ { | } .
        let badCharacters = CharacterSet(charactersIn: "~\"#%&:*<>?/\\{|}.")
        if oldFileNameWithoutExtension.rangeOfCharacter(from: badCharacters) != nil {
            needsRenaming = true
            var tmpName = ""
            for character in oldFileNameWithoutExtension {
                switch character {
                case "~", "\"", "#", "%", "&", ":", "*", "<", ">", "?", "/", "\\", "{", "|", "}", ".":
                    tmpName.append("-")
                default:
                    tmpName.append(character)
                }
            }
            newFileNameWithoutExtension = tmpName
        } else {
            newFileNameWithoutExtension = oldFileNameWithoutExtension
        }
        
        // At this point, 0 or more changes have been made to the original file name sans extension
        // As such, let's check if we're flagged for a change
        if needsRenaming {
            // If we need to rename the file, we also need to rejoin the file extension if there was one
            if fileExtension.isEmpty {
                // No extension so we can just use the existing string
                newFileName = newFileNameWithoutExtension
            } else {
                // There is a file extension and it needs to be added
                newFileName = "\(newFileNameWithoutExtension).\(fileExtension)"
            }
            guard rename(file: oldFile, to: newFileName, isDirectory: isDirectory) != nil else { return }
        } else {
            // If we're not flagged, we can return without any modifications.
            return
        }
        
        
    }

    func rename(file oldFile: URL, to newFileName: String, isDirectory: Bool) -> URL? {
        // Rebuild the path using components
        var pathComponents = oldFile.pathComponents.dropLast()
        pathComponents.append(newFileName)
        var newPathString = ""
        for pathComponent in pathComponents {
            newPathString.append(pathComponent)
            newPathString.append("/")
        }
        // Get rid of the extra '/' character
        newPathString.removeLast()
        // Build the new file URL from the path string
        let newFile = URL.init(fileURLWithPath: newPathString, isDirectory: isDirectory)
        do {
            try FileManager.default.moveItem(at: oldFile, to: newFile)
            output(message: "Renamed: \(oldFile.absoluteString.dropFirst(7)) -> \(newFile.absoluteString.dropFirst(7))")
            return newFile
        } catch {
            output(message: "Error renaming \(oldFile.absoluteString.dropFirst(7)), skipping...")
            return nil
        }
    }
    
}

// MARK: - Actions

extension ViewController {
    
    @IBAction func selectFolderClicked(_ sender: Any) {
        guard let window = view.window else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Select your OneDrive root folder"
        
        panel.beginSheetModal(for: window) { (result) in
            if result == NSApplication.ModalResponse.OK {
                self.selectedFolder = panel.urls[0]
                print(self.selectedFolder ?? "Selected Folder")
                self.fileStack.push(self.selectedFolder!)
            }
        }
    }
    
    @IBAction func startButtonClicked(_ sender: NSButton) {
        if let folder = self.fileStack.peek() {
            self.textView.string = ""
            output(message: "Beginning scan of paths at: " + folder.absoluteString)
            self.fixContents(at: folder)
        } else {
            output(message: "There was an error at the start. Do you have read + write permission for the selected folder?")
        }
    }
    
    @IBAction func askBeforeRenaming(_ sender: NSButton) {
    }
    
    @IBAction func tableViewDoubleClicked(_ sender: Any) {
    }
    
    @IBAction func saveOutputClicked(_ sender: Any) {
    }
    
}

extension FileManager {
    public func existence(atUrl url: URL) -> FileExistence {
        
        var isDirectory: ObjCBool = false
        let exists = self.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        switch (exists, isDirectory.boolValue) {
        case (false, _): return .none
        case (true, false): return .file
        case (true, true): return .directory
        }
    }
}
