const STORAGE_KEY = "containerGroups";
const SETTINGS_KEY = "settings";
const MENU_ROOT_ID = "open-in-container-group-root";

function t(key, subs) {
  return browser.i18n.getMessage(key, subs);
}

/* ---------- helpers ---------- */

function randomId() {
  return Math.random().toString(16).slice(2) + Date.now().toString(16);
}

async function getGroups() {
  const data = await browser.storage.local.get(STORAGE_KEY);
  return Array.isArray(data[STORAGE_KEY]) ? data[STORAGE_KEY] : [];
}

async function getSettings() {
  const data = await browser.storage.local.get(SETTINGS_KEY);
  return Object.assign({ focusExisting: true }, data[SETTINGS_KEY] || {});
}

async function ensureInitialData() {
  const groups = await getGroups();
  if (groups.length === 0) {
    await browser.storage.local.set({
      [STORAGE_KEY]: [{ id: randomId(), name: "Default", containerIds: [] }]
    });
  }
}

async function findExistingTab(url, cookieStoreId) {
  const tabs = await browser.tabs.query({ url });
  return tabs.find(t => t.cookieStoreId === cookieStoreId) || null;
}

/* ---------- open logic (shared) ---------- */



async function openUrlInGroupByIndex(url, index) {
  if (!url || !/^https?:\/\//i.test(url)) return;

  const groups = await getGroups();
  const group = groups[index];
  if (!group) return;

  const settings = await getSettings();
  const identities = await browser.contextualIdentities.query({});
  const validIds = new Set(identities.map(ci => ci.cookieStoreId));

  for (const storeId of group.containerIds || []) {
    if (!validIds.has(storeId)) continue;

    const existing = await findExistingTab(url, storeId);
    if (existing) {
      if (settings.focusExisting) {
        await browser.tabs.update(existing.id, { active: true });
        await browser.windows.update(existing.windowId, { focused: true });
      }
      continue;
    }

    await browser.tabs.create({ url: url, cookieStoreId: storeId });
  }
}

async function openTabInGroupByIndex(tab, index) {
  if (!tab) return;
  await openUrlInGroupByIndex(tab.url, index);
}

/* ---------- context menu ---------- */

const CONTEXT_DEFS = [
  { type: "tab", rootId: "root-tab", titleKey: "menuRootTitle" },
  { type: "link", rootId: "root-link", titleKey: "menuRootTitleLink" }
];

async function rebuildContextMenus() {
  try { await browser.contextMenus.removeAll(); } catch (_) { }

  const groups = await getGroups();

  for (const ctx of CONTEXT_DEFS) {
    browser.contextMenus.create({
      id: ctx.rootId,
      title: t(ctx.titleKey),
      contexts: [ctx.type]
    });

    if (groups.length === 0) {
      browser.contextMenus.create({
        id: `no-groups-${ctx.type}`,
        parentId: ctx.rootId,
        title: t("noGroupsConfigured"),
        enabled: false,
        contexts: [ctx.type]
      });
      continue;
    }

    for (const g of groups) {
      browser.contextMenus.create({
        id: `group:${g.id}:${ctx.type}`,
        parentId: ctx.rootId,
        title: g.name || t("unnamedGroup"),
        contexts: [ctx.type]
      });
    }

    browser.contextMenus.create({
      id: `sep-${ctx.type}`,
      parentId: ctx.rootId,
      type: "separator",
      contexts: [ctx.type]
    });

    browser.contextMenus.create({
      id: `open-options-${ctx.type}`,
      parentId: ctx.rootId,
      title: t("editGroupsMenuItem"),
      contexts: [ctx.type]
    });
  }
}

browser.contextMenus.onClicked.addListener(async (info, tab) => {
  if (String(info.menuItemId).startsWith("open-options-")) {
    browser.runtime.openOptionsPage();
    return;
  }

  const url = info.linkUrl || (tab && tab.url);
  if (!url) return;

  if (!String(info.menuItemId).startsWith("group:")) return;

  // Format is "group:GROUP_ID:TYPE"
  const parts = String(info.menuItemId).split(":");
  if (parts.length < 3) return;

  const groupId = parts[1];

  const groups = await getGroups();
  const group = groups.find(g => g.id === groupId);
  if (!group) return;

  const index = groups.indexOf(group);
  await openUrlInGroupByIndex(url, index);
});

/* ---------- keyboard shortcuts ---------- */

browser.commands.onCommand.addListener(async (command) => {
  const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
  if (!tab) return;

  if (command === "open-group-1") await openTabInGroupByIndex(tab, 0);
  if (command === "open-group-2") await openTabInGroupByIndex(tab, 1);
  if (command === "open-group-3") await openTabInGroupByIndex(tab, 2);
});

/* ---------- init ---------- */

(async () => {
  await ensureInitialData();
  await rebuildContextMenus();
})();

browser.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes[STORAGE_KEY]) {
    rebuildContextMenus();
  }
});
