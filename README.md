# AE Multi-Window Tool

A comprehensive AutoHotkey script for managing multiple Ashen Empires game windows with advanced combat detection, chat monitoring, and automated features.

## Features

### 🎮 Core Functionality
- **Multi-Window Management**: Automatically detects and manages multiple Ashen Empires windows
- **Memory-Based Combat Detection**: Real-time combat state monitoring using game memory reading
- **Smart Chat Detection**: Prevents key sending when chat is active
- **Window Switching**: Seamless switching between game windows with follow commands

### ⚔️ Combat Features
- **Auto-Combat Key Sending**: Automatically sends backtick (`) key to all windows in combat
- **Q Key Behavior**: Configurable single/double press combat toggling
- **Escape Combat**: Smart escape key handling to exit combat on all windows
- **Combat State Visualization**: Real-time combat status display in GUI

### 🔧 Advanced Features
- **AEBoost Integration**: Built-in support for AutoRune functionality
- **Follow System**: Configurable follow commands when switching windows
- **Right Alt Passthrough**: Send any key to inactive windows using Right Alt + Key
- **Memory vs Cursor Detection**: Fallback to cursor color detection if admin privileges unavailable

## Installation

1. **Download AutoHotkey v2.0** from [autohotkey.com](https://www.autohotkey.com/)
2. **Clone or download this repository**
3. **Optional**: Place AEBoost files in `\AEBoost\` subfolder for AutoRune support
4. **Run** `AEMultibox.ahk`

### Admin Privileges (Recommended)
The script works best with administrator privileges for accurate memory reading. If run without admin:
- Script will prompt to restart with elevated privileges
- Falls back to cursor color detection if declined
- Some features may be limited

## Usage

### Getting Started
1. **Launch Ashen Empires** (one or more windows)
2. **Run the script** - it will automatically detect game windows
3. **Press PgUp** to start/stop the automation
4. **Monitor status** in the GUI window

### Hotkeys

| Key | Function |
|-----|----------|
| `PgUp` | Start/Stop automation (Global) |
| `Tab` | Switch windows + send follow command |
| `Q` | Toggle combat (Single=All, Double=Active by default) |
| `Right Alt + Any Key` | Send key to other window |
| `Enter` | Toggle chat mode detection |
| `Esc` | Exit chat mode & combat on all windows |

### GUI Tabs

#### Main Tab
- Real-time status monitoring
- Combat state for each window
- Chat activity detection
- Enable/disable core features

#### Settings Tab
- **Follow Settings**: Configure which key to send and when
- **Q Key Behavior**: Invert single/double press behavior
- **Right Alt Keys**: Send any key to inactive windows
- **AEBoost Integration**: Enable/disable AutoRune

#### Info Tab
- Complete hotkey reference
- Feature explanations
- Usage tips

## Configuration

### Combat Detection Modes
1. **Memory Reading** (Default with admin): Direct game memory access for instant detection
2. **Cursor Color Detection** (Fallback): Analyzes cursor color changes

### Follow System
Configure when follow commands are sent:
- **Switching To Sandbox**: Main window sends follow key when switching to alt
- **Switching From Sandbox**: Alt window sends follow key when switching to main

### Q Key Modes
- **Normal**: Single press = all windows, Double press = active window only
- **Inverted**: Single press = active window, Double press = all windows

## AEBoost Integration

The script includes built-in support for AEBoost's AutoRune feature:

1. Place AEBoost files in `\AEBoost\` subfolder
2. Enable AutoRune from the Settings tab
3. AutoRune runs silently in the background
4. Automatically manages rune swapping and refreshing

### AEBoost Structure
```
YourScript/
├── AEMultibox.ahk
└── AEBoost/
    ├── AEBoost.exe
    └── [other AEBoost files]
```

## Technical Details

### Memory Addresses
- **Global Manager**: `0x744074`
- **Combat Mode Offset**: `0x2A8`
- **Chat Base Offset**: `0x323084`
- **Chat Final Offset**: `0x6AC`

### Window Classes
- **Main Window**: `Sandbox:Ashen_empires:WindowsClass`
- **Secondary Window**: `WindowsClass`

### Requirements
- AutoHotkey v2.0+
- Windows with DLL access for memory reading
- Ashen Empires game client

## Troubleshooting

### Common Issues

**Script not detecting windows**
- Ensure Ashen Empires is running
- Check window titles match expected format
- Restart script after launching game

**Combat detection not working**
- Run script as administrator
- Verify game version compatibility
- Check memory addresses are current

**AEBoost not starting**
- Verify AEBoost.exe exists in subfolder
- Ensure game is running first
- Check file permissions

### Error Messages

**"Admin Recommended"**
- Click "Yes" for best performance
- Click "No" to use cursor detection mode

**"AEBoost.exe not found"**
- Download AEBoost and place in `\AEBoost\` subfolder
- Verify file structure matches requirements

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Development Notes
- Script uses AutoHotkey v2.0 syntax
- Memory addresses may need updates for new game versions
- GUI uses tabbed interface for organization
- Error handling includes graceful fallbacks

## License

This project is open source. Please respect Ashen Empires' Terms of Service when using automation tools.

## Disclaimer

This tool is designed for legitimate multi-boxing within the game's rules. Users are responsible for ensuring compliance with Ashen Empires' Terms of Service and any applicable game rules.

## Support

For issues, feature requests, or questions:
1. Check existing GitHub issues
2. Create a new issue with detailed description
3. Include error messages and system information

---

**Version**: 1.0  
**AutoHotkey Version**: v2.0+  
**Game Compatibility**: Ashen Empires (current version)  
**Last Updated**: 2025
