//
//  ContentView.swift
//  RAM_Disk!
//
//  Created by FreQRiDeR on 10/10/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var ramDiskManager = RAMDiskManager()
    @State private var diskName = "RAMDisk"
    @State private var diskSize: Double = 1.0
    @State private var sizeUnit: SizeUnit = .gb
    @State private var fileSystem: FileSystem = .apfs
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isCreating = false
    
    enum SizeUnit: String, CaseIterable {
        case mb = "MB"
        case gb = "GB"
        
        var multiplier: Int {
            switch self {
            case .mb: return 2048 // 512-byte sectors per MB
            case .gb: return 2048 * 1024
            }
        }
    }
    
    enum FileSystem: String, CaseIterable {
        case apfs = "APFS"
        case hfsPlus = "HFS+"
        case fat32 = "FAT32"
        case exfat = "ExFAT"
        
        var diskutilFormat: String {
            switch self {
            case .apfs: return "APFS"
            case .hfsPlus: return "HFS+"
            case .fat32: return "FAT32"
            case .exfat: return "ExFAT"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 48))
                    .accentColor(.teal)
            
                Text("RAM Disk Manager")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Create fast temporary storage in memory")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Create RAM Disk Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Create RAM Disk")
                                .font(.headline)
                            
                            // Disk Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Disk Name")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                TextField("Enter disk name", text: $diskName)
                                    .textFieldStyle(.roundedBorder)
                                    .accentColor(.teal)
                            }
                            
                            // Disk Size
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Disk Size")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 12) {
                                    TextField("Size", value: $diskSize, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    
                                    Picker("", selection: $sizeUnit) {
                                        ForEach(SizeUnit.allCases, id: \.self) { unit in
                                            Text(unit.rawValue).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 120)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(diskSize * Double(sizeUnit.multiplier) / 2048)) MB")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                            
                            // File System
                            VStack(alignment: .leading, spacing: 6) {
                                Text("File System")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("File System", selection: $fileSystem) {
                                    ForEach(FileSystem.allCases, id: \.self) { fs in
                                        Text(fs.rawValue).tag(fs)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Create Button
                            Button(action: createRAMDisk) {
                                HStack {
                                    if isCreating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                    }
                                    Text(isCreating ? "Creating..." : "Create RAM Disk")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(diskName.isEmpty || diskSize <= 0 || isCreating)
                        }
                        .padding(16)
                    }
                    
                    // Mounted RAM Disks Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Mounted RAM Disks")
                                    .font(.headline)
                                Spacer()
                                Button(action: ramDiskManager.refreshDisks) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if ramDiskManager.mountedDisks.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "externaldrive.badge.questionmark")
                                            .font(.system(size: 32))
                                            .foregroundColor(.secondary)
                                        Text("No RAM disks mounted")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(ramDiskManager.mountedDisks, id: \.self) { disk in
                                        DiskRowView(diskName: disk) {
                                            unmountDisk(disk)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .tint(.teal)
        .alert("RAM Disk Manager", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            ramDiskManager.refreshDisks()
        }
    }
    
    private func createRAMDisk() {
        guard !diskName.isEmpty, diskSize > 0 else { return }
        
        isCreating = true
        let sectors = Int(diskSize * Double(sizeUnit.multiplier))
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ramDiskManager.createRAMDisk(
                name: diskName,
                sectors: sectors,
                fileSystem: fileSystem.diskutilFormat
            )
            
            DispatchQueue.main.async {
                isCreating = false
                if result.success {
                    alertMessage = "RAM Disk '\(diskName)' created successfully at /Volumes/\(diskName)"
                    ramDiskManager.refreshDisks()
                } else {
                    alertMessage = "Failed to create RAM Disk: \(result.message)"
                }
                showingAlert = true
            }
        }
    }
    
    private func unmountDisk(_ diskName: String) {
        let alert = NSAlert()
        alert.messageText = "Unmount RAM Disk"
        alert.informativeText = "⚠️ All data on '\(diskName)' will be permanently erased! This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Unmount")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let result = ramDiskManager.unmountRAMDisk(name: diskName)
            alertMessage = result.message
            showingAlert = true
            if result.success {
                ramDiskManager.refreshDisks()
            }
        }
    }
}

struct DiskRowView: View {
    let diskName: String
    let onUnmount: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "internaldrive.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.teal, .teal.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(diskName)
                    .font(.body)
                    .fontWeight(.medium)
                Text("/Volumes/\(diskName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onUnmount) {
                HStack(spacing: 4) {
                    Image(systemName: "eject.fill")
                    Text("Unmount")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

class RAMDiskManager: ObservableObject {
    @Published var mountedDisks: [String] = []
    private var createdDisks: Set<String> = []
    
    func createRAMDisk(name: String, sectors: Int, fileSystem: String) -> (success: Bool, message: String) {
        // Escape single quotes and backslashes for shell
        let escapedName = name.replacingOccurrences(of: "'", with: "'\\''")
        
        let formatCommand: String
        switch fileSystem {
        case "APFS":
            formatCommand = "diskutil apfs create $(hdiutil attach -nomount ram://\(sectors)) '\(escapedName)' && touch /Volumes/'\(escapedName)'/."
        case "HFS+":
            formatCommand = "diskutil eraseDisk HFS+ '\(escapedName)' $(hdiutil attach -nomount ram://\(sectors)) && touch /Volumes/'\(escapedName)'/."
        case "FAT32":
            formatCommand = "diskutil eraseDisk FAT32 '\(escapedName)' MBR $(hdiutil attach -nomount ram://\(sectors)) && touch /Volumes/'\(escapedName)'/."
        case "ExFAT":
            formatCommand = "diskutil eraseDisk ExFAT '\(escapedName)' MBR $(hdiutil attach -nomount ram://\(sectors)) && touch /Volumes/'\(escapedName)'/."
        default:
            formatCommand = "diskutil apfs create $(hdiutil attach -nomount ram://\(sectors)) '\(escapedName)' && touch /Volumes/'\(escapedName)'/."
        }
        
        let script = """
        tell application "Terminal"
            activate
            do script "\(formatCommand); exit"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                if errorMessage.contains("not allowed") || errorMessage.contains("isn't allowed") {
                    return (false, "Permission denied. Please go to System Settings > Privacy & Security > Automation and enable Terminal access for RAM Disk Manager.")
                }
                return (false, "AppleScript error: \(errorMessage)")
            }
            
            // Wait a moment for the disk to mount
            sleep(3)
            
            // Set custom icon for the RAM disk
            setCustomIcon(for: name)
            
            // Track this disk as created by us
            createdDisks.insert(name)
            
            return (true, "RAM Disk created successfully")
        }
        
        return (false, "Failed to create AppleScript")
    }
    
    func unmountRAMDisk(name: String) -> (success: Bool, message: String) {
        // Escape single quotes for shell
        let escapedName = name.replacingOccurrences(of: "'", with: "'\\''")
        
        let script = """
        tell application "Terminal"
            activate
            do script "diskutil eject /Volumes/'\(escapedName)'; exit"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            
            if let error = error {
                let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error"
                if errorMessage.contains("not allowed") || errorMessage.contains("isn't allowed") {
                    return (false, "Permission denied. Please go to System Settings > Privacy & Security > Automation and enable Terminal access for RAM Disk Manager.")
                }
                return (false, "AppleScript error: \(errorMessage)")
            }
            
            sleep(2)
            
            // Remove from tracked disks
            createdDisks.remove(name)
            
            return (true, "RAM Disk '\(name)' unmounted successfully")
        }
        
        return (false, "Failed to create AppleScript")
    }
    
    func refreshDisks() {
        // Run disk detection in background to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            // Simply show disks we've created
            DispatchQueue.main.async {
                self.mountedDisks = Array(self.createdDisks).sorted()
            }
        }
    }
    
    private func setCustomIcon(for volumeName: String) {
        let volumePath = "/Volumes/\(volumeName)"
        
        // Get the path to the icon in the app bundle
        guard let bundlePath = Bundle.main.resourcePath else {
            print("Could not get bundle resource path")
            return
        }
        
        // Check multiple possible locations for the icon
        let possiblePaths = [
            "\(bundlePath)/AppIcon.icns",
            "\(bundlePath)/appicon.icns",
            "\(bundlePath)/images/appicon.icns",
            "/Volumes/HD TRE/RAM_Disk!/RAM_Disk!/images/appicon.icns"
        ]
        
        var iconSourcePath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                iconSourcePath = path
                print("Found icon at: \(path)")
                break
            }
        }
        
        guard let sourcePath = iconSourcePath else {
            print("Icon file not found in any expected location")
            return
        }
        
        // Use Terminal to copy the icon and set the custom icon flag
        let escapedSource = sourcePath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedVolume = volumePath.replacingOccurrences(of: "'", with: "'\\''")
        
        let script = """
        tell application "Terminal"
            do script "cp '\(escapedSource)' '\(escapedVolume)/.VolumeIcon.icns' && SetFile -a C '\(escapedVolume)'; exit"
        end tell
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let err = error {
                print("Icon copy error: \(err)")
            } else {
                print("Custom icon command executed for \(volumeName)")
            }
        }
    }
    
    private func copyIconToVolume(from iconURL: URL, to volumePath: String) {
        let iconPath = "\(volumePath)/.VolumeIcon.icns"
        
        do {
            // Read the icns file data
            let iconData = try Data(contentsOf: iconURL)
            
            // Write to the RAM disk
            try iconData.write(to: URL(fileURLWithPath: iconPath))
            
            // Set the custom icon flag using SetFile
            let escapedPath = volumePath.replacingOccurrences(of: "'", with: "'\\''")
            let script = """
            tell application "Terminal"
                do script "SetFile -a C '\(escapedPath)'; exit"
            end tell
            """
            
            if let scriptObject = NSAppleScript(source: script) {
                var error: NSDictionary?
                scriptObject.executeAndReturnError(&error)
                if let err = error {
                    print("SetFile error: \(err)")
                }
            }
            
            print("Custom icon set successfully for \(volumePath)")
        } catch {
            print("Failed to set custom icon: \(error)")
        }
    }
}

#Preview {
    ContentView()
}
