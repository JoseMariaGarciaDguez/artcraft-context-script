# ArtCraft Context Menu for Windows

Create ArtCraft files from **right-click → New** on the desktop or in a folder. The installer detects apps on your PC and builds starter files with their companion tools. Apps that start from a library or workspace get an **Open** entry.

## Quick start

1. [Download the ZIP](https://github.com/JoseMariaGarciaDguez/artcraft-context-script/archive/refs/heads/main.zip) and extract the entire folder.
2. Double-click **Install.cmd** and accept the Windows administrator prompt. This configures apps installed under Program Files for everyone on the computer.
3. Open **New** in File Explorer. On Windows 11, check **Show more options** if needed. Select a file type and give the file a name.

For apps installed only for your account, use the User scope below. Run the installer again after installing another ArtCraft app.

## Applications

| Product | Default action |
| --- | --- |
| CADCraft | Create a metric DXF drawing |
| DeckCraft | Create a DeckCraft presentation |
| DesignCraft | Create a DesignCraft publication |
| EffectCraft | Create an EffectCraft project |
| FigCraft | Create a FigCraft design |
| FilmCraft | Create a FilmCraft project |
| GridCraft | Create an XLSX workbook |
| MaterialCraft | Create an SBS material |
| PdfCraft | Create a blank A4 PDF page |
| PhotoCraft | Create a transparent 1024 × 768 PNG canvas |
| SoundCraft | Create a SoundCraft session |
| TextureCraft | Create a texture project with a starter cube |
| VectorCraft | Create an SVG drawing |
| WordCraft | Create a DOCX document |
| LightCraft, Craft Anything | Open the app and start a project there |
| SolidCraft, ArtCraft Launcher, ArtCraft Studio | Open the app when detected |

**File entries** create a file in the current folder. Double-clicking it uses the Windows default application for that format. **Open entries** launch the application; choose the save location inside the app. Explorer may display the file type name supplied by an existing association.

When another program already provides **New** for an extension, the installer keeps that entry and adds an Open entry for ArtCraft. It recognizes templates from the previous Spanish installer and leaves those entries in place. If a companion CLI is missing, rejects the recipe, or produces a template over 1 MiB, the installer reports the reason and registers an Open entry.

## PowerShell usage

Run from the extracted folder in Windows PowerShell 5.1 or PowerShell 7 on Windows. Machine changes require an administrator shell (64-bit on 64-bit Windows). Use the same scope for installation and removal.

```powershell
# Preview detection without changing Windows
.\ArtCraftContext.ps1 -Action List
.\ArtCraftContext.ps1 -Action List -Scope User

# Install all detected products or select individual apps
.\ArtCraftContext.ps1 -Action Install
.\ArtCraftContext.ps1 -Action Install -Scope User -Product WordCraft,GridCraft

# Remove registrations created by this version
.\ArtCraftContext.ps1 -Action Uninstall
.\ArtCraftContext.ps1 -Action Uninstall -Scope User
```

If local policy restricts scripts, run a single invocation in a separate process:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ArtCraftContext.ps1 -Action List
```

## Troubleshooting

- **Missing app in List:** Check both scopes. Machine searches standard Program Files installation directories. User also searches Local AppData and its Programs folder. Portable and custom paths are outside automatic detection.
- **Menu looks unchanged:** Close and reopen it. If needed, save your work and restart Windows Explorer from Task Manager. For a machine-wide installation, prefer Machine scope.
- **Wrong editor opens:** Use **Open with** on the new file or choose your preferred editor in Windows Settings.
- **Spanish entry remains after uninstall:** The earlier installer owns it. This version removes registrations marked as its own.

## Development

The recipes in [products.json](products.json) specify a label, extension and arguments to the installed CLI. An empty recipe opens the app. [assets](assets/) contains the PDF and PNG starters and the empty FigCraft command list. The script stores small templates directly in the ShellNew registry entry, so the downloaded folder can be removed after setup.

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Smoke.ps1` to check detection and available generators. The three office templates have been generated and reopened with the installed Windows CLIs. Other product recipes depend on the installed version. When contributing a recipe, please include the product version and confirm the file can be created from Explorer and reopened in the target app.

Community project, independent of ArtCraft. See the [official app catalog](https://getartcraft.com/apps) and [license](LICENSE).
