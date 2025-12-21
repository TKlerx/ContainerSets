const STORAGE_KEY = "containerGroups";
const SETTINGS_KEY = "settings";

function t(key, subs) {
  return browser.i18n.getMessage(key, subs);
}

function applyI18n() {
  // text content
  document.querySelectorAll("[data-i18n]").forEach(el => {
    el.textContent = t(el.getAttribute("data-i18n"));
  });
  // placeholders
  document.querySelectorAll("[data-i18n-placeholder]").forEach(el => {
    el.setAttribute("placeholder", t(el.getAttribute("data-i18n-placeholder")));
  });
  // title
  const titleEl = document.querySelector("title[data-i18n]");
  if (titleEl) document.title = t(titleEl.getAttribute("data-i18n"));
}

applyI18n();

let groups = [];
let containers = [];
let activeGroupId = null;
let dragFromIndex = null;

function randomId() {
  // crypto.randomUUID is available in modern Firefox, but keep a fallback
  if (typeof crypto !== "undefined" && crypto.randomUUID) return crypto.randomUUID();
  return Math.random().toString(16).slice(2) + Date.now().toString(16);
}

async function loadAll() {
  containers = await browser.contextualIdentities.query({});
  containers.sort((a, b) => a.name.localeCompare(b.name, document.documentElement.lang || "en"));

  const data = await browser.storage.local.get([STORAGE_KEY, SETTINGS_KEY]);
  groups = Array.isArray(data[STORAGE_KEY]) ? data[STORAGE_KEY] : [];

  const focusExisting = (data[SETTINGS_KEY]?.focusExisting ?? true);
  document.getElementById("focusExisting").checked = !!focusExisting;

  if (!activeGroupId && groups.length) activeGroupId = groups[0].id;
  if (activeGroupId && !groups.find(g => g.id === activeGroupId)) {
    activeGroupId = groups.length ? groups[0].id : null;
  }

  render();
}

async function persistGroups() {
  await browser.storage.local.set({ [STORAGE_KEY]: groups });
}

function flash(id, msgKey) {
  const el = document.getElementById(id);
  el.textContent = t(msgKey);
  setTimeout(() => (el.textContent = ""), 1200);
}

function moveGroup(from, to) {
  if (from === to || from == null || to == null) return;
  if (to < 0 || to >= groups.length) return;
  const [item] = groups.splice(from, 1);
  groups.splice(to, 0, item);
}

function renderGroups() {
  const gdiv = document.getElementById("groups");
  gdiv.innerHTML = "";

  document.getElementById("groupCount").textContent = groups.length ? `(${groups.length})` : "(0)";

  if (groups.length === 0) {
    const p = document.createElement("p");
    p.className = "muted";
    p.textContent = t("noGroupsConfigured");
    gdiv.appendChild(p);
    return;
  }

  groups.forEach((g, idx) => {
    const row = document.createElement("div");
    row.className = "group-row" + (g.id === activeGroupId ? " active" : "");
    row.draggable = true;
    row.dataset.index = String(idx);

    // badge for shortcut mapping
	const badge = document.createElement("span");
	badge.className = "badge";

	const shortcutNumber =
	  idx === 0 ? 1 :
	  idx === 1 ? 2 :
	  idx === 2 ? 3 : null;

	badge.textContent = shortcutNumber ? `#${shortcutNumber}` : "";
	if (!badge.textContent) {
	  badge.style.visibility = "hidden";
	} else {
	  // Tooltip (i18n)
	  badge.setAttribute(
		"data-tooltip",
		t("shortcutBadgeTooltip", [String(shortcutNumber)])
	  );
	}


    const name = document.createElement("span");
    name.className = "group-name";
    name.textContent = g.name || t("unnamedGroup");

    row.appendChild(badge);
    row.appendChild(name);

    // Click selects group (avoid conflict with drag: click still fine)
    row.addEventListener("click", () => {
      activeGroupId = g.id;
      render();
    });

    // Drag & Drop handlers
    row.addEventListener("dragstart", (e) => {
      dragFromIndex = idx;
      row.classList.add("dragging");
      e.dataTransfer.setData("text/plain", String(idx));
      e.dataTransfer.effectAllowed = "move";
    });

    row.addEventListener("dragend", () => {
      dragFromIndex = null;
      row.classList.remove("dragging");
      document.querySelectorAll(".group-row.drop-target").forEach(el => el.classList.remove("drop-target"));
    });

    row.addEventListener("dragover", (e) => {
      e.preventDefault(); // allow drop
      e.dataTransfer.dropEffect = "move";
      row.classList.add("drop-target");
    });

    row.addEventListener("dragleave", () => {
      row.classList.remove("drop-target");
    });

    row.addEventListener("drop", async (e) => {
      e.preventDefault();
      row.classList.remove("drop-target");

      const from = (dragFromIndex != null) ? dragFromIndex : Number(e.dataTransfer.getData("text/plain"));
      const to = Number(row.dataset.index);

      if (Number.isNaN(from) || Number.isNaN(to)) return;

      moveGroup(from, to);
      await persistGroups();
      render();
      flash("editStatus", "savedStatus"); // optional i18n key; see note below
    });

    gdiv.appendChild(row);
  });
}

function renderEditor() {
  const group = groups.find(g => g.id === activeGroupId);

  const nameInput = document.getElementById("groupName");
  const containersDiv = document.getElementById("containers");
  const containerHint = document.getElementById("containerHint");
  const saveBtn = document.getElementById("saveGroup");
  const delBtn = document.getElementById("deleteGroup");

  containersDiv.innerHTML = "";

  if (!group) {
    nameInput.value = "";
    nameInput.disabled = true;
    containerHint.textContent = "";
    saveBtn.disabled = true;
    delBtn.disabled = true;

    const p = document.createElement("p");
    p.className = "muted";
    p.textContent = t("noGroupsConfigured");
    containersDiv.appendChild(p);
    return;
  }

  nameInput.disabled = false;
  saveBtn.disabled = false;
  delBtn.disabled = false;

  nameInput.value = group.name || "";

  const selected = new Set(group.containerIds || []);
  containerHint.textContent = t("selectedCount", [String(selected.size)]) || `${selected.size}`;

  containers.forEach(ci => {
    const row = document.createElement("label");
    row.className = "container-row";

    const cb = document.createElement("input");
    cb.type = "checkbox";
    cb.value = ci.cookieStoreId;
    cb.checked = selected.has(ci.cookieStoreId);

    cb.addEventListener("change", () => {
      const g = groups.find(x => x.id === activeGroupId);
      if (!g) return;

      const set = new Set(g.containerIds || []);
      if (cb.checked) set.add(ci.cookieStoreId);
      else set.delete(ci.cookieStoreId);
      g.containerIds = [...set];

      const newCount = g.containerIds.length;
      containerHint.textContent = t("selectedCount", [String(newCount)]) || `${newCount}`;
    });

    const label = document.createElement("span");
    label.textContent = ci.name;

    row.appendChild(cb);
    row.appendChild(label);
    containersDiv.appendChild(row);
  });
}

function render() {
  renderGroups();
  renderEditor();
}

/* ---------- UI actions ---------- */

document.getElementById("newGroup").addEventListener("click", async () => {
  const g = { id: randomId(), name: t("newGroupDefaultName") || "New group", containerIds: [] };
  groups.push(g);
  activeGroupId = g.id;
  await persistGroups();
  render();
  flash("editStatus", "savedStatus");
});

document.getElementById("saveGroup").addEventListener("click", async () => {
  const group = groups.find(g => g.id === activeGroupId);
  if (!group) return;

  const name = document.getElementById("groupName").value.trim();
  group.name = name || t("unnamedGroup");

  await persistGroups();
  render();
  flash("editStatus", "savedStatus");
});

document.getElementById("deleteGroup").addEventListener("click", async () => {
  const idx = groups.findIndex(g => g.id === activeGroupId);
  if (idx === -1) return;

  groups.splice(idx, 1);
  activeGroupId = groups.length ? groups[Math.max(0, idx - 1)].id : null;

  await persistGroups();
  render();
  flash("editStatus", "savedStatus");
});

document.getElementById("focusExisting").addEventListener("change", async (e) => {
  await browser.storage.local.set({ [SETTINGS_KEY]: { focusExisting: !!e.target.checked } });
  flash("settingsStatus", "savedStatus");
});

loadAll().catch(console.error);
