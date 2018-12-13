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
    
    // MARK: - Properties
    var fileStack = DirectoryStack()
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
        
        // As long as we have something in the stack, lets' rename some stuff
        while !self.fileStack.isEmpty() {
            self.currentDirectory = self.fileStack.pop()!
            do {
                let contents = try FileManager.default.contentsOfDirectory(at: self.currentDirectory, includingPropertiesForKeys: [], options: [])
                var index = 0
                for content in contents {
                    // Rename the content of the folder
                    validateName(of: content, at: index, isDirectory: FileManager.default.existence(atUrl: content) == FileExistence.directory)
                    index += 1
                }
            } catch {
                print("Error during enumeration")
            }
        }
        
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

// MARK: - Fix Path Name

extension ViewController {
    
    // TO-DO: - This is big and ugly. Make it Swifty please.
    func validateName(of path: URL, at index: Int, isDirectory: Bool) {
        var containsIllegalCharacters = false
        var isInvalidName = false
        var components = path.pathComponents
        let name = path.lastPathComponent
        var newName = "default"
        var newPath: String
        var newURL: URL
        var nameWithoutExtension = name
        
        // Get the filename without the extension; if there is one
        let fileExtension = path.pathExtension
        if !fileExtension.isEmpty {
            nameWithoutExtension = String(name.dropLast(fileExtension.count + 1))
        }
        

        // Drop the extension from the file name
        if !fileExtension.isEmpty {
            nameWithoutExtension = String(name.dropLast(fileExtension.count + 1))
        }
        
        
        // Safely ignore DS_Store
        if name == ".DS_Store" {
            return
        }
        
        // No matter what, we're going to trim whitespace from the beginning of the filename
        // Also trimming whitespace from the end of the filename (excluding extension)
        
        
        // Invalid characters:
        // " * : < > ? / \ |
        let badCharacters = CharacterSet(charactersIn: "~\"#%&:*<>?/\\{|}.")
        if name.rangeOfCharacter(from: badCharacters) != nil {
            containsIllegalCharacters = true
        } else {
            print("Contains no invalid characters")
        }
        
        switch name {
            // Invalid files or folder names:
        // .lock, CON, PRN, AUX, NUL, COM1 - COM9, LPT1 - LPT9, _vti_, desktop.ini, any filename starting with ~$.
        case ".lock","CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9",
             "LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9","desktop.ini":
            isInvalidName = true
        default:
            print("Valid file or folder name")
        }
        // '_vti_' is prohibited ANYWHERE in the filename
        if name.contains("_vti_") {
            print("Illegal filename: '_vti_' detected at \(path.absoluteString)")
            isInvalidName = true
        }
        // 'forms' dissalowed at root level of One Drive
        if path.deletingLastPathComponent() == self.selectedFolder && name == "forms" && isDirectory == false {
            print("Illegal filename: 'forms' detected at \(path.absoluteString)")
            newName = "formsFile"
            isInvalidName = true
        }
        
        if isInvalidName {
            if isDirectory {
                newName = "FOLDER\(index)"
            } else {
                newName = "FILE\(index)"
            }
            components[components.count - 1] = newName
            newPath = ""
            for component in components {
                newPath.append(component)
                newPath.append("/")
            }
            newPath.removeLast()
            newURL = URL.init(fileURLWithPath: newPath, isDirectory: isDirectory)
            do {
                try FileManager.default.moveItem(at: path, to: newURL)
                output(message: "Renamed: \(path.absoluteString.dropFirst(7)) -> \(newURL.absoluteString.dropFirst(7))")
            } catch {
                output(message: "Error renaming \(path.absoluteString.dropFirst(7)), skipping...")
                return
            }
        }
        
        if containsIllegalCharacters {
            // Wipe the newName variable and build up the new name
            var newName = ""
            // Check each character for an illegal character and replace as necessary
            for character in nameWithoutExtension {
                switch character {
                case "~", "\"", "#", "%", "&", ":", "*", "<", ">", "?", "/", "\\", "{", "|", "}", ".":
                    newName.append("-")
                default:
                    newName.append(character)
                }
            }
            // Rejoin the file extension
            if !fileExtension.isEmpty {
                newName = "\(newName).\(fileExtension)"
            }
            
            // Replace the last component with the new file name
            components[components.count - 1] = newName
            newPath = ""
            for component in components {
                newPath.append(component)
                newPath.append("/")
            }
            newPath.removeLast()
            newURL = URL.init(fileURLWithPath: newPath, isDirectory: isDirectory)
            do {
                try FileManager.default.moveItem(at: path, to: newURL)
                output(message: "Renamed \(path.absoluteString.dropFirst(7)) -> \(newURL.absoluteString.dropFirst(7))")
            } catch {
                output(message: "Error renaming \(path.absoluteString.dropFirst(7)), skipping...")
                return
            }
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
