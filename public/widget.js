/**
 * LoopAI embeddable widget.
 *
 * Usage on a third-party site:
 *
 *   Floating button (bottom-right by default):
 *     <script src="https://yourloopai.app/widget.js" data-loop-slug="abc123"></script>
 *
 *   Inline embed (renders where the tag sits):
 *     <script src="https://yourloopai.app/widget.js" data-loop-slug="abc123" data-mode="inline"></script>
 *
 * Options (all via data-* attributes on the script tag):
 *   data-loop-slug   (required) the loop's public slug
 *   data-mode        "widget" (default) or "inline"
 *   data-position     "bottom-right" (default) or "bottom-left" -- widget mode only
 */
(function () {
  "use strict";

  function init(scriptTag) {
    var slug = scriptTag.getAttribute("data-loop-slug");
    if (!slug) return;

    var origin = new URL(scriptTag.src).origin;
    var url = origin + "/i/" + slug;
    var mode = scriptTag.getAttribute("data-mode") || "widget";

    if (mode === "inline") {
      renderInline(scriptTag, url);
    } else {
      renderFloatingWidget(scriptTag, url);
    }
  }

  function buildIframe(url) {
    var iframe = document.createElement("iframe");
    iframe.src = url;
    iframe.setAttribute("allow", "microphone");
    iframe.style.border = "none";
    return iframe;
  }

  function renderInline(scriptTag, url) {
    var iframe = buildIframe(url);
    iframe.style.width = "100%";
    iframe.style.height = "640px";
    iframe.style.borderRadius = "12px";
    scriptTag.parentNode.insertBefore(iframe, scriptTag.nextSibling);
  }

  function renderFloatingWidget(scriptTag, url) {
    var position = scriptTag.getAttribute("data-position") === "bottom-left" ? "left" : "right";
    var overlay = null;

    var button = document.createElement("button");
    button.type = "button";
    button.textContent = "💬 Feedback";
    button.setAttribute("aria-label", "Give feedback");
    Object.assign(button.style, {
      position: "fixed",
      bottom: "20px",
      zIndex: 999999,
      padding: "12px 20px",
      borderRadius: "999px",
      border: "none",
      background: "#0D6EFD",
      color: "#fff",
      fontSize: "14px",
      fontFamily: "system-ui, sans-serif",
      cursor: "pointer",
      boxShadow: "0 4px 12px rgba(0,0,0,0.2)"
    });
    button.style[position] = "20px";

    button.addEventListener("click", function () {
      if (overlay) {
        overlay.remove();
        overlay = null;
        return;
      }

      overlay = document.createElement("div");
      Object.assign(overlay.style, {
        position: "fixed",
        bottom: "84px",
        zIndex: 999999,
        width: "380px",
        maxWidth: "calc(100vw - 40px)",
        height: "560px",
        maxHeight: "calc(100vh - 120px)",
        borderRadius: "12px",
        overflow: "hidden",
        boxShadow: "0 8px 30px rgba(0,0,0,0.25)"
      });
      overlay.style[position] = "20px";

      var iframe = buildIframe(url);
      iframe.style.width = "100%";
      iframe.style.height = "100%";
      overlay.appendChild(iframe);
      document.body.appendChild(overlay);
    });

    document.body.appendChild(button);
  }

  var scripts = document.querySelectorAll("script[data-loop-slug]");
  for (var i = 0; i < scripts.length; i++) {
    init(scripts[i]);
  }
})();
