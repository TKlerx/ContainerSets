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

async function openTabInGroupByIndex(tab, index) {
  if (!tab || !tab.url || !/^https?:\/\//i.test(tab.url)) return;

  const groups = await getGroups();
  const group = groups[index];
  if (!group) return;

  const settings = await getSettings();
  const identities = await browser.contextualIdentities.query({});
  const validIds = new Set(identities.map(ci => ci.cookieStoreId));

  for (const storeId of group.containerIds || []) {
    if (!validIds.has(storeId)) continue;

    const existing = await findExistingTab(tab.url, storeId);
    if (existing) {
      if (settings.focusExisting) {
        await browser.tabs.update(existing.id, { active: true });
        await browser.windows.update(existing.windowId, { focused: true });
      }
      continue;
    }

    await browser.tabs.create({ url: tab.url, cookieStoreId: storeId });
  }
}

/* ---------- context menu ---------- */

async function rebuildContextMenus() {
  try { await browser.contextMenus.removeAll(); } catch (_) {}

  browser.contextMenus.create({
    id: MENU_ROOT_ID,
    title: t("menuRootTitle"),
    contexts: ["tab"]
  });

  const groups = await getGroups();

  if (groups.length === 0) {
    browser.contextMenus.create({
      id: "no-groups",
      parentId: MENU_ROOT_ID,
      title: t("noGroupsConfigured"),
      enabled: false,
      contexts: ["tab"]
    });
    return;
  }

  for (const g of groups) {
    browser.contextMenus.create({
      id: `group:${g.id}`,
      parentId: MENU_ROOT_ID,
      title: g.name || t("unnamedGroup"),
      contexts: ["tab"]
    });
  }

  browser.contextMenus.create({
    id: "sep",
    parentId: MENU_ROOT_ID,
    type: "separator",
    contexts: ["tab"]
  });

  browser.contextMenus.create({
    id: "open-options",
    parentId: MENU_ROOT_ID,
    title: t("editGroupsMenuItem"),
    contexts: ["tab"]
  });
}

browser.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab || !tab.url || !/^https?:\/\//i.test(tab.url)) return;

  if (info.menuItemId === "open-options") {
    browser.runtime.openOptionsPage();
    return;
  }

  if (!String(info.menuItemId).startsWith("group:")) return;

  const groups = await getGroups();
  const group = groups.find(g => `group:${g.id}` === info.menuItemId);
  if (!group) return;

  const index = groups.indexOf(group);
  await openTabInGroupByIndex(tab, index);
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
