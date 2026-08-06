"use strict";

const MENU_ID = "dia-router-open-other";

function isWebURL(rawURL) {
  try {
    const url = new URL(rawURL);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function buildRouterURL(rawURL) {
  const query = new URLSearchParams({
    url: rawURL,
    profile: "Other"
  });
  return `dia-router://open?${query.toString()}`;
}

function installContextMenu() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_ID,
      title: "Open link in other Dia profile",
      contexts: ["link"],
      targetUrlPatterns: ["http://*/*", "https://*/*"]
    });
  });
}

chrome.runtime.onInstalled.addListener(installContextMenu);
chrome.runtime.onStartup.addListener(installContextMenu);

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (
    info.menuItemId !== MENU_ID ||
    !info.linkUrl ||
    !isWebURL(info.linkUrl) ||
    tab.id === undefined
  ) {
    return;
  }

  chrome.tabs
    .update(tab.id, { url: buildRouterURL(info.linkUrl) })
    .catch((error) => console.error("Dia Router could not open the link:", error));
});
