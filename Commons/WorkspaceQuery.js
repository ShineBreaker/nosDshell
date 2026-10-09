.pragma library

// WorkspaceQuery.js — "哪些工作区属于这块屏"的单一裁决点，任务栏空白区滚轮
// 切换（Bar.qml）与工作区挂件显示（Workspace.qml）共用，避免同一筛选谓词
// 两处独立维护后漂移。

// followFocusedScreen 模式下的匹配目标：聚焦工作区所在输出的名字（小写）。
// 不提前 break（保持与挂件刷新一致的"取最后一个聚焦项"语义），
// 无聚焦项时返回 null，此时候选集随之为空。
function focusedOutput(workspaces) {
  var output = null;
  for (var i = 0; i < workspaces.count; i++) {
    var ws = workspaces.get(i);
    if (ws.isFocused)
      output = ws.output.toLowerCase();
  }
  return output;
}

// 返回 workspaces 中属于这块屏的原始工作区对象（保持原有顺序）。
// opts.globalWorkspaces: 全局工作区模式（如 LabWC）下全部工作区属于所有屏；
// opts.followFocusedScreen: 开启时按聚焦输出 opts.focusedOutput 匹配
// （由 focusedOutput() 探测后传入）；
// opts.screenName: 物理屏幕名（小写），followFocusedScreen 关闭时按它匹配。
function workspacesForScreen(workspaces, opts) {
  var target = opts.followFocusedScreen ? opts.focusedOutput : opts.screenName;
  var candidates = [];
  for (var i = 0; i < workspaces.count; i++) {
    var ws = workspaces.get(i);
    var output = ws.output ? ws.output.toLowerCase() : null;
    if (opts.globalWorkspaces || (output !== null && output === target))
      candidates.push(ws);
  }
  return candidates;
}
