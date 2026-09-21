const $ = (id) => document.getElementById(id);
const status = (text) => { $("status").textContent = text; };

function collectSnapshot() {
  const visible = (el) => {
    const s = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    return s.display !== "none" && s.visibility !== "hidden" && r.width > 0 && r.height > 0;
  };
  const clean = (s) => String(s || "").replace(/\s+/g, " ").trim();
  const labelFor = (el) => {
    const labels = el.labels ? Array.from(el.labels).map(x => clean(x.innerText)).filter(Boolean) : [];
    if (labels.length) return labels.join(" ");
    const aria = clean(el.getAttribute("aria-label"));
    if (aria) return aria;
    const ph = clean(el.getAttribute("placeholder"));
    if (ph) return ph;
    const fs = el.closest("fieldset");
    const legend = fs?.querySelector("legend");
    if (legend) return clean(legend.innerText);
    return clean(el.name || el.id || el.type || "field");
  };
  const safePart = (s) => clean(s).toLowerCase().replace(/[^a-z0-9_-]+/g, "-").slice(0, 50);
  const controls = Array.from(document.querySelectorAll("input,select,textarea"))
    .filter(el => !el.disabled && visible(el) &&
      !["hidden","submit","button","reset","file"].includes((el.type || "").toLowerCase()));
  const questions = [];
  const radioSeen = new Set();
  let seq = 0;
  for (const el of controls) {
    const type = (el.type || el.tagName || "text").toLowerCase();
    if (type === "radio") {
      const name = el.name || ("radio-" + seq++);
      if (radioSeen.has(name)) continue;
      radioSeen.add(name);
      const group = controls.filter(x => (x.type || "").toLowerCase() === "radio" && (x.name || "") === name);
      const key = "vyrm-radio-" + (safePart(name) || seq++);
      group.forEach(x => x.dataset.vyrKey = key);
      questions.push({
        key, label: labelFor(el), kind: "radio", required: group.some(x => x.required),
        answered: group.some(x => x.checked),
        value: group.find(x => x.checked)?.value ?? "",
        options: group.map(x => ({value: x.value, label: labelFor(x)}))
      });
      continue;
    }

    const key = "vyrm-" + (seq++) + "-" + safePart(el.name || el.id || type);
    el.dataset.vyrKey = key;
    let kind = "text";
    let options = [];
    let value = el.value ?? "";
    let answered = clean(value) !== "";
    if (el.tagName === "SELECT") {
      kind = "select";
      options = Array.from(el.options).map(o => ({value:o.value,label:clean(o.textContent)}));
    } else if (type === "checkbox") {
      kind = "checkbox";
      value = !!el.checked;
      answered = !!el.checked;
    } else if (["number","email","tel","date"].includes(type)) {
      kind = type;
    }
    questions.push({key, label: labelFor(el), kind, required: !!el.required, answered, value, options});
  }
  const pageText = clean(document.body?.innerText).slice(0, 6000);
  const lower = pageText.toLowerCase();
  const blocked = [
    "captcha", "verify you are human", "attention check",
    "i agree", "consent", "certify", "attest"
  ].find(x => lower.includes(x)) || "";
  const buttons = Array.from(document.querySelectorAll("button,input[type=submit]")).filter(visible);
  const finalButton = buttons.find(b =>
    /\b(submit|finish|complete|confirm)\b/i.test(clean(b.innerText || b.value))
  );
  return {
    title: document.title || "",
    url: location.origin + location.pathname,
    origin: location.origin,
    page_text: pageText,
    questions,
    blocked_gate: blocked,
    final_gate: finalButton ? clean(finalButton.innerText || finalButton.value) : ""
  };
}

function applyPlan(plan) {
  const allowed = new Set(["FILL_FIELD","SELECT_OPTION","CHECK"]);
  const dispatch = (el) => {
    el.dispatchEvent(new Event("input", {bubbles:true}));
    el.dispatchEvent(new Event("change", {bubbles:true}));
  };
  const setValue = (el, value) => {
    const proto = el instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype
      : el instanceof HTMLSelectElement ? HTMLSelectElement.prototype : HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, "value")?.set;
    if (setter) setter.call(el, String(value ?? ""));
    else el.value = String(value ?? "");
    dispatch(el);
  };
  let applied = 0;
  for (const action of (plan.actions || [])) {
    if (!allowed.has(action.action) || !action.key) continue;
    const els = Array.from(document.querySelectorAll("[data-vyr-key]"))
      .filter(x => x.dataset.vyrKey === action.key);
    if (!els.length) continue;
    if (action.action === "SELECT_OPTION" && els[0].type === "radio") {
      const target = els.find(x => String(x.value) === String(action.value));
      if (target) { target.checked = true; dispatch(target); applied++; }
    } else if (action.action === "CHECK") {
      const el = els[0];
      el.checked = !!action.value;
      dispatch(el);
      applied++;
    } else {
      setValue(els[0], action.value);
      applied++;
    }
  }
  return {applied};
}
async function getPairingToken() {
  const stored = await browser.storage.local.get("vyrMobileToken");
  let token = String(stored?.vyrMobileToken || "").trim();
  if (token.length < 24) {
    token = String(prompt("Paste your VYR Mobile pairing token") || "").trim();
    if (token.length < 24) throw new Error("VYR Mobile is not paired");
    await browser.storage.local.set({vyrMobileToken: token});
  }
  return token;
}

async function run() {
  status("Reading current Safari page…");
  try {
    const [tab] = await browser.tabs.query({active:true,currentWindow:true});
    if (!tab?.id) throw new Error("No active tab");
    const collected = await browser.scripting.executeScript({
      target:{tabId:tab.id},
      func:collectSnapshot
    });
    const snapshot = collected?.[0]?.result;
    if (!snapshot) throw new Error("Could not read this page");
    status("VYR → local reasoner (" + snapshot.questions.length + " fields)…");

    const token = await getPairingToken();
    const response = await browser.runtime.sendNativeMessage(
      "net.vyres.AirTranslate13Mini",
      {type:"VYR_MOBILE_REASON", snapshot, token}
    );
    if (response?.status === 401) {
      await browser.storage.local.remove("vyrMobileToken");
      throw new Error("Pairing expired. Tap again and paste the new token.");
    }
    if (!response?.ok || !response.plan?.ok) {
      throw new Error(response?.plan?.error || response?.error || "Reasoner failed");
    }

    const plan = response.plan;
    const applied = await browser.scripting.executeScript({
      target:{tabId:tab.id},
      func:applyPlan,
      args:[plan]
    });
    const count = applied?.[0]?.result?.applied || 0;
    const needs = Array.isArray(plan.needs_user) ? plan.needs_user : [];
    if (needs.length) {
      const labels = needs.slice(0,3)
        .map(x => x.label || x.reason)
        .filter(Boolean)
        .join("\n• ");
      status(count + " safe answer" + (count === 1 ? "" : "s") +
        " filled.\nNeeds you:\n• " + labels);
    } else {
      status(count + " safe answer" + (count === 1 ? "" : "s") +
        " filled. Review the page, then tap Next yourself.");
    }
  } catch (err) {
    status("Stopped safely: " + (err?.message || err));
  }
}

$("run").addEventListener("click", run);
