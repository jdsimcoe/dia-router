(() => {
  "use strict";

  function findClickedLink(event) {
    for (const element of event.composedPath()) {
      if (element instanceof HTMLAnchorElement && element.href) {
        return element;
      }
    }
    return null;
  }

  function isWebURL(rawURL) {
    try {
      const url = new URL(rawURL);
      return url.protocol === "http:" || url.protocol === "https:";
    } catch {
      return false;
    }
  }

  function buildRouterURL(rawURL) {
    const query = new URLSearchParams({ url: rawURL });
    return `dia-router://open?${query.toString()}`;
  }

  document.addEventListener(
    "click",
    (event) => {
      const isRouterGesture =
        event.button === 0 &&
        event.metaKey &&
        event.shiftKey &&
        !event.altKey &&
        !event.ctrlKey;

      if (!isRouterGesture) {
        return;
      }

      const link = findClickedLink(event);
      if (!link || !isWebURL(link.href)) {
        return;
      }

      event.preventDefault();
      event.stopImmediatePropagation();
      window.location.assign(buildRouterURL(link.href));
    },
    true
  );
})();
