// Web host: battery saves live in /saves (<exe dir>/saves; the exe dir is "/" here), backed by IndexedDB.
Module.preRun = Module.preRun || [];
Module.preRun.push(function () {
  // the host loop yields itself (web/yield.h); SDL must not suspend inside calls made through pointers
  ENV.SDL_EMSCRIPTEN_ASYNCIFY = '0';
  FS.mkdir('/saves');
  FS.mount(IDBFS, {}, '/saves');
  addRunDependency('mdweb-saves');
  FS.syncfs(true, function (err) {
    if (err) console.error('[mdweb] loading saves from IndexedDB failed', err);
    removeRunDependency('mdweb-saves');
    // the runner writes saves atomically on its own schedule; mirror /saves when it changes
    var last = '';
    setInterval(function () {
      var sig = '';
      try {
        FS.readdir('/saves').forEach(function (n) {
          if (n === '.' || n === '..') return;
          var st = FS.stat('/saves/' + n); sig += n + ':' + st.size + ':' + (+st.mtime) + ';';
        });
      } catch (e) { return; }
      if (sig === last) return;
      last = sig;
      FS.syncfs(false, function (e) {
        if (e) console.error('[mdweb] writing saves to IndexedDB failed', e);
        if (Module.onSavesSynced) Module.onSavesSynced(e);
      });
    }, 1000);
  });
});
