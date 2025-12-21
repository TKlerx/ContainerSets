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

---

## 🧠 How it works

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

## 🇩🇪 Deutsch

### Container Sets – Tabs in Container-Gruppen öffnen

**Container Sets** ermöglicht es, den aktuellen Tab gleichzeitig in mehreren
Firefox-Containern zu öffnen.

Statt dieselbe Seite manuell in verschiedenen Containern neu zu öffnen,
kannst du Container-Gruppen definieren und sie mit einem Klick oder
Tastenkürzel öffnen.

---

## 📦 Build & Release

A signed `.xpi` file can be built using:

```powershell
.\build-release.ps1
```
## Author
Timo Klerx

github: https://github.com/TKlerx/ContainerSets

## License

This project is licensed under the
GNU General Public License v3.0 or later (GPL-3.0-or-later).

## 🤖 Development Note

Parts of this project were developed with the assistance of AI-based tools.
All code was reviewed, tested, and finalized by the author.