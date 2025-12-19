# 🦀 Oxide Master Swift - Native macOS Edition

A powerful **native macOS application** built with **Swift and SwiftUI** for disk analysis, backup management, file synchronization, and cache cleanup.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-blue)

## ✨ Features

### 1. 📊 Disk Analyzer
- **3 View Modes**: 
  - **List View**: Sortable flat file browser
  - **Tree View**: Hierarchical tree structure like WinDirStat (expandable folders)
  - **TreeMap**: Interactive visualization with color-coded rectangles
- **Fast Scanning**: Parallel directory scanning for optimal performance
- **Delete Operations**: Move files to trash with confirmation
- **File Type Recognition**: Color-coded categories for easy identification
- **Percentage Bars**: Visual indication of disk space usage per file/folder

### 2. 💾 Backup Manager
- **Date-Based Filtering**: Backup only files modified within X days
- **Preserve Structure**: Maintain original folder hierarchy
- **Manual Trigger**: Run backups on demand
- **History Tracking**: Complete log of all backup operations
- **Progress Reporting**: Real-time feedback during backup

### 3. 📁 File Synchronization
- **Dual-Pane Browser**: WinSCP-style interface for easy file management
- **Copy/Move Operations**: Transfer files between panels
- **Session Management**: Save and load favorite folder pairs
- **Drag & Drop**: Native macOS drag and drop support
- **Multi-Selection**: Operate on multiple files at once

### 4. 🗑️ Cache Manager
- **Automatic Cleanup**: Schedule periodic cache removal
- **Smart Detection**: Find cache folders across system
- **Age-Based Filtering**: Delete only old cache files
- **Manual Cleanup**: Run cleanup anytime
- **History & Statistics**: Track freed space over time

## 🚀 Getting Started

### Prerequisites
- **macOS 13.0 (Ventura)** or later
- **Xcode 15.0** or later
- **Swift 5.9** or later

### Building from Source

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/disk_oxide_swift.git
cd disk_oxide_swift
```

2. **Open in Xcode**
```bash
open OxideMaster.xcodeproj
```

3. **Build and Run**
- Press `Cmd + R` to build and run
- Or select `Product > Run` from menu

### Permissions

The app uses **standard file picker dialogs** for folder selection. No special permissions required!

- When you select a folder, macOS automatically grants access
- No Full Disk Access needed
- All operations are user-controlled and secure

## 🏗️ Project Structure

```
OxideMaster/
├── OxideMasterApp.swift          # App entry point
├── ContentView.swift            # Main tab view
├── Models/                      # Data models
│   ├── FileInfo.swift
│   ├── BackupConfig.swift
│   ├── CacheSettings.swift
│   └── SyncSession.swift
├── ViewModels/                  # MVVM ViewModels
│   ├── DiskAnalyzerViewModel.swift
│   ├── BackupManagerViewModel.swift
│   ├── FileSyncViewModel.swift
│   └── CacheManagerViewModel.swift
├── Views/                       # SwiftUI Views
│   ├── DiskAnalyzer/
│   │   ├── DiskAnalyzerView.swift
│   │   ├── FileListView.swift
│   │   └── TreeMapView.swift
│   ├── BackupManager/
│   │   ├── BackupManagerView.swift
│   │   └── BackupHistoryView.swift
│   ├── FileSync/
│   │   ├── FileSyncView.swift
│   │   └── FilePanel.swift
│   └── CacheManager/
│       ├── CacheManagerView.swift
│       ├── CacheSettingsView.swift
│       └── CacheHistoryView.swift
├── Services/                    # Business logic
│   ├── FileScanner.swift
│   ├── FileOperationsService.swift
│   ├── BackupService.swift
│   ├── CacheCleanerService.swift
│   └── SchedulerService.swift
└── Utilities/
    ├── Extensions.swift
    ├── Constants.swift
    └── PermissionHelper.swift
```

## 🎨 Architecture

### MVVM Pattern
- **Models**: Data structures (FileInfo, BackupConfig, etc.)
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Business logic and state management
- **Services**: Core functionality (file operations, scanning, etc.)

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for data flow
- **FileManager**: Native file system operations
- **DispatchQueue**: Concurrent operations for performance
- **UserDefaults**: Settings and configuration persistence
- **UserNotifications**: Background cleanup notifications

## 🆚 Comparison with Tauri Version

| Feature | Tauri (Rust + Svelte) | Native Swift |
|---------|----------------------|--------------|
| App Size | ~80-100 MB | ~5-10 MB |
| Memory Usage | Higher (WebView) | Lower (Native) |
| Startup Time | ~2-3 seconds | <1 second |
| macOS Integration | Limited | Full native support |
| File Operations | Via FFI | Direct native APIs |
| Performance | Good | Excellent |
| Distribution | Code signing needed | Code signing needed |

### Advantages of Native Swift

✅ **Smaller footprint** - No embedded browser  
✅ **Faster performance** - Direct API access  
✅ **Better integration** - Native macOS features  
✅ **Lower memory** - No WebView overhead  
✅ **Native look & feel** - 100% macOS UI  

## 🔧 Development

### Running Tests
```bash
# Unit tests
xcodebuild test -scheme OxideMaster

# Or press Cmd+U in Xcode
```

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint for consistency
- Document public APIs

### Contributing
Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Original Tauri version: [Oxide Master](../disk_oxide)
- Inspired by WinDirStat, WinSCP, and macOS native tools
- Built with love for the macOS community

## 📧 Contact

For questions or support, please open an issue on GitHub.

---

**Made with ❤️ in Swift for macOS**
