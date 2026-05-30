/* tunnela — one continuous animation explaining the tunnels.
   Tunnels are flowing "rivers" (continuous CSS flow). Discrete dots only
   appear for app-to-app data demos. Everything else is a function of t. */
(function () {
  "use strict";

  /* ---------------- timeline (seconds) ---------------- */
  var GROW_D = 1.3;
  var T = {
    hostGrow: 1.0, hostFlow: 2.3,
    clientGrow: 3.0, clientFlow: 4.3,
    junction: 5.0,
    svcGrow: 6.0, svcFlow: 7.3, svcServer: 7.6, svcClient: 8.0,
    svcDots: [8.7, 8.98, 9.26, 10.55, 10.83, 11.11], svcTravel: 1.7, svcRemove: 13.2,
    homenet: 13.6, lanBorn: 13.9,
    socksGrow: 14.5, socksFlow: 15.8, egressLan: 14.8,
    socksServer: 16.1, socksClient: 16.1,
    slanDots: [16.7, 16.98, 17.26, 18.55, 18.83, 19.11], slanTravel: 1.9, lanRemove: 21.5,
    inetBorn: 22.0, egressNet: 19.3,
    snetDots: [22.6, 22.88, 23.16, 24.45, 24.73, 25.01], snetTravel: 2.0,
    endClear: 27.5, endD: 1.1
  };
  var TOTAL = 28.7;

  /* ---------------- helpers ---------------- */
  var $ = function (id) { return document.getElementById(id); };
  function clamp01(x){ return x < 0 ? 0 : x > 1 ? 1 : x; }
  function smooth(x){ x = clamp01(x); return x * x * (3 - 2 * x); }
  function fIn(t, s, d){ return smooth((t - s) / d); }
  function fOut(t, s, d){ return 1 - smooth((t - s) / d); }
  function lin(t, s, d){ return clamp01((t - s) / d); }
  function setOp(el, v){ el.style.opacity = v; }

  /* ---------------- element refs ---------------- */
  function G(name){
    var tube = $(name + "-tube"), flow = $(name + "-flow"), sheen = $(name + "-sheen");
    var L = tube.getTotalLength();
    tube.style.strokeDasharray = L;
    tube.style.strokeDashoffset = L;
    tube.style.opacity = 0;
    return { tube: tube, flow: flow, sheen: sheen, L: L };
  }
  var tubes = {
    host:    [G("host-out"), G("host-in")],
    client:  [G("client-out"), G("client-in")],
    service: [G("service")],
    socks:   [G("socks")]
  };

  var dpaths = {
    svc:  { el: $("dp-svc") },
    slan: { el: $("dp-slan") },
    snet: { el: $("dp-snet") }
  };
  Object.keys(dpaths).forEach(function (k){ dpaths[k].L = dpaths[k].el.getTotalLength(); });

  var dots = {
    svc:  Array.prototype.slice.call(document.querySelectorAll(".d-svc")),
    slan: Array.prototype.slice.call(document.querySelectorAll(".d-slan")),
    snet: Array.prototype.slice.call(document.querySelectorAll(".d-snet"))
  };
  var jring = $("jring");

  /* ---------------- tube rendering ---------------- */
  function tubeState(arr, tubeAlpha, growFrac, flowAlpha){
    for (var i = 0; i < arr.length; i++){
      var g = arr[i];
      g.tube.style.opacity = tubeAlpha;
      g.tube.style.strokeDashoffset = g.L * (1 - growFrac);
      g.flow.style.opacity = flowAlpha;
      if (g.sheen) g.sheen.style.opacity = flowAlpha * 0.55;
    }
  }

  /* ---------------- dot rendering ---------------- */
  function dotOpacity(p){
    if (p <= 0 || p >= 1) return 0;
    return Math.min(1, Math.min(p, 1 - p) / 0.07);
  }
  function renderDots(group, dp, emits, travel, t){
    var arrival = 0;
    group.forEach(function (el, i){
      var p = (t - emits[i]) / travel;
      if (p <= 0 || p >= 1){ el.style.opacity = 0; return; }
      var pt = dp.el.getPointAtLength(p * dp.L);
      el.setAttribute("cx", pt.x);
      el.setAttribute("cy", pt.y);
      el.style.opacity = dotOpacity(p);
      if (p > 0.9) arrival = Math.max(arrival, (p - 0.9) / 0.1);
    });
    return arrival; // 0..1, for target-app pulse
  }

  function pulse(el, amt, baseX, baseY){
    el.style.transform = "translate(-50%,-50%) scale(" + (1 + 0.07 * amt) + ")";
  }

  /* ---------------- port highlight ---------------- */
  function setPort(id, cls){
    var el = $(id);
    el.className = "port" + (cls ? " " + cls : "");
  }

  /* ---------------- main render ---------------- */
  function render(t){
    var endFade = fOut(t, T.endClear, T.endD);

    /* HOST (persists, clears at loop) */
    (function(){
      var alive = fIn(t, T.hostGrow, 0.15) * endFade;
      var gf = lin(t, T.hostGrow, GROW_D);
      var flow = fIn(t, T.hostFlow, 0.4) * endFade;
      tubeState(tubes.host, alive, gf, flow);
      setOp($("lbl-host"), fIn(t, T.hostGrow + 0.3, 0.5) * endFade);
    })();

    /* CLIENT */
    (function(){
      var alive = fIn(t, T.clientGrow, 0.15) * endFade;
      var gf = lin(t, T.clientGrow, GROW_D);
      var flow = fIn(t, T.clientFlow, 0.4) * endFade;
      tubeState(tubes.client, alive, gf, flow);
      setOp($("lbl-client"), fIn(t, T.clientGrow + 0.3, 0.5) * endFade);
    })();

    /* YOU-ARE-HERE silhouette — appears after Host tunnel, stays to the end */
    setOp($("you-here"), fIn(t, 2.6, 0.5) * endFade);

    /* JUNCTION pulse at relay:22222 */
    (function(){
      var lp = lin(t, T.junction, 1.5);
      var on = fIn(t, T.junction, 0.2) * fOut(t, T.junction + 1.3, 0.4);
      jring.setAttribute("r", 9 + 34 * lp);
      jring.style.opacity = on * (1 - lp) * 0.9;
    })();

    /* SERVICE (removed mid-way) */
    var svcAlive = (t >= T.svcGrow ? 1 : 0) * fOut(t, T.svcRemove, 0.6);
    (function(){
      var gf = lin(t, T.svcGrow, GROW_D);
      var flow = fIn(t, T.svcFlow, 0.4) * fOut(t, T.svcRemove, 0.5);
      tubeState(tubes.service, svcAlive, gf, flow);
      setOp($("lbl-service"), fIn(t, T.svcGrow + 0.3, 0.5) * fOut(t, T.svcRemove, 0.5));
    })();
    setOp($("app-svc-server"), fIn(t, T.svcServer, 0.4) * fOut(t, T.svcRemove, 0.5));
    setOp($("app-svc-client"), fIn(t, T.svcClient, 0.4) * fOut(t, T.svcRemove, 0.5));

    /* HOME NETWORK region + LAN device */
    setOp($("homenet"), fIn(t, T.homenet, 0.6) * endFade);
    var lanAlive = fIn(t, T.lanBorn, 0.5) * fOut(t, T.lanRemove, 0.6);
    setOp($("m-lan"), lanAlive);
    setOp($("app-soc-server"), fIn(t, T.socksServer, 0.4) * fOut(t, T.lanRemove, 0.5));

    /* SOCKS tube ends at Home Mac :22 — beyond that is ordinary outbound traffic, NOT a tunnel */
    (function(){
      var alive = (t >= T.socksGrow ? 1 : 0) * endFade;
      var gf = lin(t, T.socksGrow, GROW_D);
      var flow = fIn(t, T.socksFlow, 0.4) * endFade;
      tubeState(tubes.socks, alive, gf, flow);
      setOp($("lbl-socks"), fIn(t, T.socksGrow + 0.3, 0.5) * endFade);
    })();
    setOp($("app-soc-client"), fIn(t, T.socksClient, 0.4) * endFade);

    /* INTERNET */
    setOp($("m-inet"), fIn(t, T.inetBorn, 0.5) * endFade);

    /* DOTS */
    var aSvc  = renderDots(dots.svc,  dpaths.svc,  T.svcDots,  T.svcTravel,  t);
    var aSlan = renderDots(dots.slan, dpaths.slan, T.slanDots, T.slanTravel, t);
    var aSnet = renderDots(dots.snet, dpaths.snet, T.snetDots, T.snetTravel, t);
    pulse($("app-svc-server"), aSvc);
    pulse($("app-soc-server"), aSlan);
    pulse($("m-inet"), aSnet, 0, 0);

    /* PORT highlights */
    var hostOn = t >= T.hostGrow && endFade > 0.05;
    var clientOn = t >= T.clientGrow && endFade > 0.05;
    var svcOn = svcAlive > 0.2;
    var socksOn = t >= T.socksGrow && endFade > 0.05;

    setPort("p-relay-22", "exposed");
    setPort("p-relay-22222", (clientOn ? "lit-on" : hostOn ? "lit-host" : ""));
    setPort("p-home-22", socksOn ? "lit-socks" : hostOn ? "lit-host" : "");
    setPort("p-home-B", svcOn ? "lit-service" : "");
    setPort("p-your-22222", (svcOn || socksOn) ? "lit-on" : clientOn ? "lit-client" : "");
    setPort("p-your-A", svcOn ? "lit-service" : "");
    setPort("p-your-1080", socksOn ? "lit-socks" : "");
  }

  /* ---------------- clock + UI ---------------- */
  var t = 0, playing = true, last = null, raf = null;
  try { t = Math.min(TOTAL, Math.max(0, parseFloat(localStorage.getItem("tunnela_t") || "0"))); } catch (e) {}

  var scrub = $("scrub"), timeEl = $("time"), playBtn = $("playBtn");

  function syncUI(){
    scrub.value = String(Math.round((t / TOTAL) * 1000));
    timeEl.textContent = t.toFixed(1) + " / " + TOTAL.toFixed(1) + "s";
  }
  var saveTick = 0;
  function frame(ts){
    if (last == null) last = ts;
    var dt = (ts - last) / 1000; last = ts;
    if (playing){
      t += dt;
      if (t >= TOTAL) t -= TOTAL;   // seamless loop (end state == base)
      saveTick += dt;
      if (saveTick > 0.3){ saveTick = 0; try { localStorage.setItem("tunnela_t", t.toFixed(2)); } catch (e) {} }
    }
    render(t);
    syncUI();
    raf = requestAnimationFrame(frame);
  }

  function setPlaying(p){
    playing = p;
    playBtn.textContent = p ? "❚❚" : "▶";
  }
  playBtn.addEventListener("click", function(){ setPlaying(!playing); });
  scrub.addEventListener("input", function(){
    setPlaying(false);
    t = (parseFloat(scrub.value) / 1000) * TOTAL;
    try { localStorage.setItem("tunnela_t", t.toFixed(2)); } catch (e) {}
    render(t); syncUI();
  });
  document.addEventListener("keydown", function(e){
    if (e.key === " "){ e.preventDefault(); setPlaying(!playing); }
    else if (e.key === "ArrowLeft"){ setPlaying(false); t = Math.max(0, t - 0.3); render(t); syncUI(); }
    else if (e.key === "ArrowRight"){ setPlaying(false); t = Math.min(TOTAL, t + 0.3); render(t); syncUI(); }
  });

  /* ---------------- scale to viewport ---------------- */
  var board = $("board");
  function fit(){
    var s = Math.min((window.innerWidth - 40) / 1280, (window.innerHeight - 110) / 720, 1);
    board.style.transform = "scale(" + s + ")";
  }
  window.addEventListener("resize", fit);
  fit();

  setPlaying(true);
  raf = requestAnimationFrame(frame);

  /* ---------------- capture hook (for GIF export; no effect on normal use) ---------------- */
  var flowEls = Array.prototype.slice.call(document.querySelectorAll(".flow, .sheen"));
  window.tunnelaSeek = function (tf) {
    setPlaying(false);
    if (raf) { cancelAnimationFrame(raf); raf = null; }
    t = tf;
    flowEls.forEach(function (el) {
      var isSheen = el.classList.contains("sheen");
      var rev = el.classList.contains("rev");
      var period = isSheen ? 0.8 : 1.15;
      var span = isSheen ? 56 : 56; // dashoffset travel per period
      var ph = (tf / period) % 1;
      var off = (rev ? 1 : -1) * span * ph;
      el.style.animation = "none";
      el.style.strokeDashoffset = off;
    });
    render(tf);
    syncUI();
  };
  window.tunnelaTotal = TOTAL;
})();
