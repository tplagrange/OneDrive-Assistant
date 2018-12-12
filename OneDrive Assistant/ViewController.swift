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

// MARK: - Depth First Search over Contents

extension ViewController {
    
    func recurse(through folder: URL) -> Void {
        if self.fileStack.isEmpty() {
            print("No more directories in the stack")
            return
        }
        self.currentDirectory = folder
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [], options: [])
            for content in contents {
                if FileManager.default.existence(atUrl: content) == FileExistence.directory {
                    print("\(content.absoluteString) is a directory")
                    self.fileStack.push(content)
                } else  {
                    print("\(content.absoluteString) is a file")
                }
            }
        } catch {
            print("Error during enumeration")
        }
        //print("Popped: " + self.fileStack.pop()!.absoluteString)
        return
    }
}

// MARK: - Fix Path Name

extension ViewController {
    
    func fixPathName(of path: URL, atIndex: Int) -> URL {
        var containsIllegalCharacters = false
        var isInvalidFileName = false
        
        let name = path.lastPathComponent
        // Invalid characters:
        // " * : < > ? / \ |
        let badCharacters = CharacterSet(charactersIn: "\"*:<>?/\\|").inverted
        if name.rangeOfCharacter(from: badCharacters) != nil {
            containsIllegalCharacters = true
        }
        
        switch name {
            // Invalid files or folder names:
        // .lock, CON, PRN, AUX, NUL, COM1 - COM9, LPT1 - LPT9, _vti_, desktop.ini, any filename starting with ~$.
        case ".lock","CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9",
             "LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9","desktop.ini":
            isInvalidFileName = true
        default:
            print("Valid file or folder name")
            
        }
        // '_vti_' is prohibited ANYWHERE in the filename
        if name.contains("_vti_") {
            print("Illegal filename: '_vti_' detected at \(path.absoluteString)")
            isInvalidFileName = true
        }
        // 'forms' dissalowed at root level of One Drive
        if self.selectedFolder == self.currentDirectory && name == "forms" {
            print("Illegal filename: 'forms' detected at \(path.absoluteString)")
        }
        
        
        return path
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
            self.textView.string.append("\nBeginning scan of paths at: " + folder.absoluteString)
            self.recurse(through: folder)
        } else {
            self.textView.string.append("\nThere was an error at the start")
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
