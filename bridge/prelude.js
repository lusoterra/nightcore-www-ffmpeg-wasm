/*! ffmpeg-core.js - nightcore audio engine for the web.
 * Copyright (C) 2026 Lev <https://lusosterone.net>
 * Built from https://git.lusosterone.net/lev/nightcore-www-ffmpeg-wasm
 * (FFmpeg + Rubber Band + LAME + Opus, compiled to WebAssembly).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * See <https://www.gnu.org/licenses/> for the full text.
 *
 * Behavior adapted from ffmpeg.wasm's own core prelude (MIT licensed,
 * https://github.com/ffmpegwasm/ffmpeg.wasm): the worker calls
 * createFFmpegCore({...}) then drives exec()/ffprobe()/ret/reset plus
 * FS and the standard runtime methods. Our C bridge/ provides the
 * _ffmpeg/_ffprobe entries behind exec()/ffprobe().
 */
/* NOTE: do NOT `var Module = ...` unconditionally here: depending on
 * toolchain version this prelude runs before OR after emcc's own
 * `var Module = moduleArg`. Always prefer the real moduleArg object and
 * never the factory function itself (reading `fn["arguments"]` on a
 * strict function throws -- that was a real production crash). */
var Module = (typeof moduleArg != "undefined" && moduleArg && typeof moduleArg == "object") ? moduleArg : (typeof Module != "undefined" ? Module : {});
var readyPromiseResolve, readyPromiseReject;
Module["ready"] = new Promise(function (resolve, reject) { readyPromiseResolve = resolve; readyPromiseReject = reject; });
var NULL = 0;
var SIZE_I32 = 4;
var DEFAULT_ARGS = ["./ffmpeg", "-nostdin", "-y"];
var DEFAULT_ARGS_FFPROBE = ["./ffprobe"];
Module["NULL"] = NULL;
Module["SIZE_I32"] = SIZE_I32;
Module["DEFAULT_ARGS"] = DEFAULT_ARGS;
Module["DEFAULT_ARGS_FFPROBE"] = DEFAULT_ARGS_FFPROBE;
Module["ret"] = -1;
Module["timeout"] = -1;
Module["logger"] = function () {};
Module["progress"] = function () {};
function stringToPtr(str) {
  var len = Module["lengthBytesUTF8"](str) + 1;
  var ptr = Module["_malloc"](len);
  Module["stringToUTF8"](str, ptr, len);
  return ptr;
}
function stringsToPtr(strs) {
  var len = strs.length;
  var ptr = Module["_malloc"](len * SIZE_I32);
  for (var i = 0; i < len; i++) Module["setValue"](ptr + SIZE_I32 * i, stringToPtr(strs[i]), "i32");
  return ptr;
}
function print(message) { Module["logger"]({ type: "stdout", message: message }); }
function printErr(message) {
  if (!String(message).startsWith("Aborted(native code called abort())"))
    Module["logger"]({ type: "stderr", message: message });
}
function exec() {
  var _args = Array.prototype.slice.call(arguments);
  var args = DEFAULT_ARGS.concat(_args);
  try { Module["_ffmpeg"](args.length, stringsToPtr(args)); }
  catch (e) { if (!String(e && e.message).startsWith("Aborted")) throw e; }
  return Module["ret"];
}
function ffprobe() {
  var _args = Array.prototype.slice.call(arguments);
  var args = DEFAULT_ARGS_FFPROBE.concat(_args);
  try { Module["_ffprobe"](args.length, stringsToPtr(args)); }
  catch (e) { if (!String(e && e.message).startsWith("Aborted")) throw e; }
  return Module["ret"];
}
function setLogger(logger) { Module["logger"] = logger; }
function setTimeout(timeout) { Module["timeout"] = timeout; }
function setProgress(handler) { Module["progress"] = handler; }
function receiveProgress(progress, time) { Module["progress"]({ progress: progress, time: time }); }
function reset() { Module["ret"] = -1; Module["timeout"] = -1; }
function _locateFile(path, prefix) {
  // Same mainScriptUrlOrBlob encoding the stock loader sends, so a
  // self-hosted {coreURL,wasmURL} pair resolves without extra config.
  var mainScriptUrlOrBlob = Module["mainScriptUrlOrBlob"];
  if (mainScriptUrlOrBlob) {
    try {
      var meta = JSON.parse(atob(mainScriptUrlOrBlob.slice(mainScriptUrlOrBlob.lastIndexOf("#") + 1)));
      if (path.endsWith(".wasm")) return meta.wasmURL;
      if (path.endsWith(".worker.js")) return meta.workerURL;
    } catch (e) {}
  }
  return prefix + path;
}
Module["stringToPtr"] = stringToPtr;
Module["stringsToPtr"] = stringsToPtr;
Module["print"] = print;
Module["printErr"] = printErr;
Module["locateFile"] = _locateFile;
Module["exec"] = exec;
Module["ffprobe"] = ffprobe;
Module["setLogger"] = setLogger;
Module["setTimeout"] = setTimeout;
Module["setProgress"] = setProgress;
Module["reset"] = reset;
Module["receiveProgress"] = receiveProgress;
