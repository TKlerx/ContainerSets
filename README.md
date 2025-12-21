# Container Sets 🗂️

**Open the current tab in multiple Firefox Containers at once.**

Container Sets is a Firefox add-on that allows you to open the same tab
simultaneously in multiple Firefox Container tabs using configurable
container groups, context menus, or keyboard shortcuts.

This is especially useful if you work with multiple accounts, identities,
or environments and want to open the same page in several containers
without repetitive manual steps.

---

## ✨ Features

- Open the current tab in **multiple containers at once**
- Create and manage **custom container groups**
- **Keyboard shortcuts** for the first three groups
- **Drag & drop** to reorder groups  
  (group order = shortcut order)
- **Avoids duplicate tabs**
- Fully local – **no tracking, no analytics, no network requests**
- Full internationalization (currently EN / DE)

---

## 🧠 How It Works

1. Open the add-on options
2. Create one or more container groups
3. Assign Firefox containers to each group
4. Open a tab using:
   - Right-click on a tab → *Open tab in container set*
   - A keyboard shortcut (configurable in Firefox)

The tab is opened once per container in the selected group.  
If a tab already exists in a container, the add-on switches to it instead
of opening a duplicate.

---

## ⌨️ Keyboard Shortcuts

By default, keyboard shortcuts are assigned to the **first three container
groups**.

You can change shortcuts via:

**Firefox → Add-ons and Themes → Extensions → ⚙️ → Manage Extension Shortcuts**

---

## 🔐 Privacy & Data Usage

Container Sets is designed with privacy as a core principle:

- ❌ No data collection
- ❌ No analytics
- ❌ No telemetry
- ❌ No remote code execution
- ❌ No network communication

All configuration and settings are stored locally using Firefox’s
`storage.local` API.

---

## 🛠️ Permissions Explained

| Permission | Reason |
|-----------|--------|
| `tabs` | Open and manage browser tabs |
| `contextMenus` | Add the tab context menu entry |
| `contextualIdentities` | Access Firefox Containers |
| `cookies` | Required by Firefox to open tabs in specific containers |
| `storage` | Store container groups and settings locally |

---

## 🧩 Compatibility

- Firefox Desktop
- Manifest Version 3 (MV3)
- Requires a Firefox version supporting container APIs

---

## 🚀 Creating a New Release

This project follows **Semantic Versioning** and **Keep a Changelog**.
Releases are created via Git tags and built automatically using GitHub Actions.

### Prerequisites
- All changes for the release are listed under `## [Unreleased]` in `CHANGELOG.md`
- PowerShell 7+ (`pwsh`) is installed
- You have push rights to the repository

---

### Step-by-Step Release Process

#### 1. Update the version
Update the version number in `manifest.json`:

```json
{
  "version": "1.1.0"
}
```
#### 2. Prepare the changelog

Move all entries from ## [Unreleased] into a new version section:

```
pwsh ./scripts/prepare-release.ps1
```

This will:
* create a new section like ## [1.1.0] – YYYY-MM-DD
* move all unreleased changes into it
* reset ## [Unreleased] for future development

Review CHANGELOG.md after running the script.

#### 3. Local Validation (Recommended)
Before creating a Git tag, you can run the full validation and build
process locally to catch errors early.

```bash
pwsh ./scripts/validate-changelog.ps1 -Version 1.1.0
pwsh ./build-release.ps1
```
This will verify that:
* CHANGELOG.md contains a valid entry for the given version
* the changelog follows the expected structure
* the version in manifest.json is usable
* the add-on builds successfully
* the generated .xpi has a valid Firefox-compatible structure

If any of these checks fail, the scripts will exit with an error.
Fix the reported issue before proceeding with the release.

Running these checks locally is optional, but strongly recommended to
avoid failed CI runs or broken releases.

#### 4. Commit the release changes
```bash
git add manifest.json CHANGELOG.md
git commit -m "Release 1.1.0"
```
#### 5. Create and push the Git tag
```bash
git tag v1.1.0
git push origin v1.1.0
```

#### 6. Automated build & release
After pushing the tag:
* GitHub Actions builds the .xpi file
* The version is validated against manifest.json
* Release notes are generated from CHANGELOG.md
* A GitHub Release is created automatically
* The built .xpi is attached as a release asset

No manual build or upload steps are required.
## 📦 Build & Release

### Local Build

A Firefox-compatible `.xpi` file can be built locally using PowerShell
(cross-platform via `pwsh`):

```bash
pwsh ./build-release.ps1
```
The build process:
* uses a strict allowlist
* ensures correct XPI folder structure
* enforces POSIX-style paths (/) inside the archive
* validates required directories (_locales, options, icons)

The resulting .xpi file is written to:
./release

### Automated Releases (GitHub Actions)

Releases are built automatically using GitHub Actions:
* A Git tag in the form vX.Y.Z triggers the release workflow
* The version in manifest.json must match the tag
* The .xpi is built in CI and attached to the GitHub Release
* Release notes are generated directly from CHANGELOG.md
This guarantees reproducible and verifiable release artifacts.

## 🧑‍💻 Development
Requirements:
* PowerShell 7+ (pwsh)
* Git
* Firefox (for local testing)

## Author 
Timo Klerx 
github: https://github.com/TKlerx/ContainerSets 

## License 
This project is licensed under the GNU General Public License v3.0 or later (GPL-3.0-or-later). 
## 🤖 Development Note 
Parts of this project were developed with the assistance of AI-based tools. All code was reviewed, tested, and finalized by the author.