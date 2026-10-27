# Changelog

每次发版时，本文件中对应版本的条目就是 GitHub Release 的正文（流程见 `docs/RELEASE.md`）。
日常开发把变化记在 `[Unreleased]` 下，发版时改成新版号并写上日期。

条目结构（自 v1.1.1 起）分三部分。开头一段面向用户的简介，可以带宣传口吻，用一两句话概括本次全部改动。
然后是一条 `---` 分割线。正文按类别列出做了什么，每条引用相关 commit，不复述实现细节。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，tag 命名为 `v<版号>`。

## [Unreleased]

## [1.6.3] - 2026-10-27

控制中心与设置里的模块图标终于成了一家人：此前 DDE 原版剪影、仓库自绘仿品和
Tabler 描边字形三套并排，线宽粗细对不上；现在统一到 Papirus 的单色 symbolic 家族，
跟随你当前的图标主题解析，主题缺图时用打包副本兜底，未选中态靠不透明度分级而
不是另存一份素材。

另一处修的是半透明遮罩的磨砂：通知、OSD、桌面挂件这些浮在真实窗口之上的半透明层
此前被 niri 的模糊强制关闭规则误判在门外，看上去"透明但不糊"；现在这些层会正式
发布模糊区域，磨砂按设计生效。

另外把三个 quickshell 系的开发 skill 一并入库，方便后续接着演进。

---

### 新功能

- unify module icons on the Papirus symbolic family：[`72ccf749e`](https://github.com/ShineBreaker/nosDshell/commit/72ccf749edff001395ee177708468780e6269c6f)
- publish blur regions from remaining translucent surfaces：[`d4b624891`](https://github.com/ShineBreaker/nosDshell/commit/d4b62489139eebc6db378df9067eeef0a97047c3)
- 从 hermes 平移 quickshell 系三个 skill 入库：[`2642d4a8c`](https://github.com/ShineBreaker/nosDshell/commit/2642d4a8c2002f848821e0d2b001e8f7a0cf6e8e)

### 修复

- move blur-region publishers out of the force-off layer tier：[`790c4324c`](https://github.com/ShineBreaker/nosDshell/commit/790c4324cd34c5c59900e2ad27da2eab98e1bdfb)

## [1.6.2] - 2026-10-24

这一版修掉一个在 Qt 6.12 下暴露的界面问题：设置面板、控制中心这类带背景的窗口一打开就整块发黑，界面几乎全透明，底栏也跟着失色——原因是新版本 Qt 引入了一个同名的颜色类型，把主题色单例挡在了后面，主题色全部取空。现在主题色重新由自己的令牌接管，面板恢复半透明磨砂，底栏配色与之前一致。

同时把一类"越攒越多"的常驻进程收干净：深浅色守护进程此前每启动一次就多排一份新的等待队列，现在全局只保留一份；剪贴板监听、事件流、网络与设备监控等子进程改为随主进程一同退出，崩溃后不再留在后台悄悄吃内存。

另外修正了输出分辨率变更后壁纸背景被清掉的问题，以及构建时会随 channel 漂移的问题。

---

### 新功能

- add IPC/property-debug hooks for live shell introspection：[`4ff30d8ba`](https://github.com/ShineBreaker/nosDshell/commit/4ff30d8ba541c70fd6fd0e405f8fb0b3f1264f50)

### 修复

- use try_lock for portal daemon so duplicate spawns exit fast：[`ecc6db1db`](https://github.com/ShineBreaker/nosDshell/commit/ecc6db1dbdc4c32fd7d56976056fadf10f8a16d9)
- rename Color singleton to Colors to escape Qt 6.12 QQuickColor shadowing：[`e2e8198c6`](https://github.com/ShineBreaker/nosDshell/commit/e2e8198c6507f872b79859ec20f8287d994ef77d)
- build nosdshell inside guix time-machine pinned to channel.lock：[`832a5eac6`](https://github.com/ShineBreaker/nosDshell/commit/832a5eac6d13dc51eecf8faf8757115d812ae2e3)
- compare screens by name so background survives output renegotiation：[`c61e1d7be`](https://github.com/ShineBreaker/nosDshell/commit/c61e1d7be15c02215bff3dcb22c31cc3b6589bcc)
- make managed child processes die with the shell (PR_SET_PDEATHSIG)：[`cafe892df`](https://github.com/ShineBreaker/nosDshell/commit/cafe892dff1d7813ab9e3c9bd87d4d558d36a2fd)

### 工程

- update `.gitignore`：[`f0b1ed33d`](https://github.com/ShineBreaker/nosDshell/commit/f0b1ed33d4d195a69a82ab591de2311423efef13)

## [1.6.1] - 2026-10-23

这一版修掉一个会卡死整个会话的问题：按时间自动切换深浅色时，日出日落边界可能触发深色/浅色每秒两次的死斗——主题、GTK 设置和夜灯钩子被反复拉起，桌面直接冻住。根因（边界定时器提前触发后又被旧逻辑反向写回）已铲除，边界处现在只翻一次。顺带还带上了一批挂件生命期修复、设置页与启动器的性能优化，以及网络、VPN、图标解析的若干小修。

---

### 修复

- stop schedule-boundary fight that flipped dark/light in a loop：[`ebfc52450`](https://github.com/ShineBreaker/nosDshell/commit/ebfc52450fe3f23d5fddc6d467fd84845d05d532)

### 其他

- commit numeric widget settings on finished editing only：[`5ee5599dd`](https://github.com/ShineBreaker/nosDshell/commit/5ee5599dd504afea98b4a6e4e953c75678d176cd)
- fix four lifecycle and value bugs in shared widgets：[`0a608d19c`](https://github.com/ShineBreaker/nosDshell/commit/0a608d19c569e18d810d1214b7a0da72e68477ac)
- stop paying for the settings view before anyone opens it：[`7a969d6fb`](https://github.com/ShineBreaker/nosDshell/commit/7a969d6fb1d6052255fff5452ab4448060b9fae2)
- stop rebuilding the launcher result set on every open：[`179ce7d3f`](https://github.com/ShineBreaker/nosDshell/commit/179ce7d3fab9a275e0d1bcc92eef2af3c75b1749)
- keep transient service-name resolution across dialog shows：[`c40485119`](https://github.com/ShineBreaker/nosDshell/commit/c404851190f491332467491d01bef46c9f1d7707)
- resolve fashion-dock workspace filter on every backend：[`5a7f2993a`](https://github.com/ShineBreaker/nosDshell/commit/5a7f2993a87270ed543f347fc4734b11db354ed3)
- count discovery owners in the service instead of each surface：[`65b20b047`](https://github.com/ShineBreaker/nosDshell/commit/65b20b0474eabd1cf62464da29001094aa58b4ef)
- poll VPN connections slowly when no profiles exist：[`a5f82eb2e`](https://github.com/ShineBreaker/nosDshell/commit/a5f82eb2e18e6a820ad218ccd05f283e0058d7dd)
- keep the nmcli monitor alive across NetworkManager restarts：[`20bd7a8b4`](https://github.com/ShineBreaker/nosDshell/commit/20bd7a8b45e2e827c561c4546676290d2d9b4c5c)
- cache icon-name resolution and cap fuzzy fallback at one result：[`5978a07f2`](https://github.com/ShineBreaker/nosDshell/commit/5978a07f2c6f3f78929fd24ce87e37436d744f1e)
- floor popup alpha at 0.9 without blur and mute write-echo reloads：[`d72830ff7`](https://github.com/ShineBreaker/nosDshell/commit/d72830ff71ea6870bb0a6ffc386df71530201cd8)
- force explicit reload when the translation path is unchanged：[`61138f714`](https://github.com/ShineBreaker/nosDshell/commit/61138f714ed9280c13246b213d7e32df4e4748a2)
- guard settings load against corrupt JSON and unreadable files：[`062376f39`](https://github.com/ShineBreaker/nosDshell/commit/062376f39f0a49a2649a08f965ec23d1e42b12bb)

## [1.6.0] - 2026-10-20

这一版把两块「看着像、用不了」的地方改成了真家伙：高效任务栏的排布从写死的布局变成可编辑模型，配套的分区式 widget 编辑器让你自己决定每个格子里放什么；时尚坞的应用条则换上一套统一的模型与动画，应用进出时沿边缘交错滑入。底下顺手扫掉了一批 ListModel 的老毛病——空值写入、委托角色类型、绑定里读行元素导致的报错与漏渲染，连带着工作区胶囊切换、任务栏溢出收缩、亮色主题强调色可读性一起修好，界面文案与 README 也全部重写了一遍。

---

### 新功能

- staggered edge-slide lifecycle for app-strip add/remove：[`0028f73ca`](https://github.com/ShineBreaker/nosDshell/commit/0028f73ca35c28e38857edb08ce857f4b4737673)
- unify app-strip model/animation and make fashion dock content configurable：[`1340797da`](https://github.com/ShineBreaker/nosDshell/commit/1340797da27fb525d32a71bc9c5390f0876d0b03)
- tighten UI copy and converge widget/plugin display names：[`e82c68ce4`](https://github.com/ShineBreaker/nosDshell/commit/e82c68ce4fb56a858402fceb13da1ba2d351b182)
- sectioned widget editor for the efficient taskbar：[`c4a013d58`](https://github.com/ShineBreaker/nosDshell/commit/c4a013d583105dd97bc6347993df5320f448bf90)
- make the efficient taskbar layout a real editable model：[`89bb23529`](https://github.com/ShineBreaker/nosDshell/commit/89bb235298cd67467b33d3eed28f1bbe01da529f)

### 修复

- never write null values into workspace ListModel rows：[`5f999bc07`](https://github.com/ShineBreaker/nosDshell/commit/5f999bc0750129b75edd57b5e8a88c182ab64d94)
- make workspace delegate roles var and coerce backend fields：[`17ab267c0`](https://github.com/ShineBreaker/nosDshell/commit/17ab267c02b4648777833b28339ad1134cbe39aa)
- purge binding-side reads of live ListModel row elements：[`0076ef3c5`](https://github.com/ShineBreaker/nosDshell/commit/0076ef3c5149caa62f682e8d410e5c34b4139ddc)
- incubation-safe list models for the dock/taskbar strips：[`225550277`](https://github.com/ShineBreaker/nosDshell/commit/2255502773f43928bbcc04849b1d2d16d073891f)
- host dialogs on the blur surface and stop cross-model widget writes：[`6e1385f45`](https://github.com/ShineBreaker/nosDshell/commit/6e1385f45cdf4a7ce2c2905d82415554220f1292)
- animate workspace pill on focus switch：[`38cedb5fe`](https://github.com/ShineBreaker/nosDshell/commit/38cedb5fedff6974779b25eaf3b4091d98c724b6)
- size overflow shrink off the zone's real free span：[`d3b10c597`](https://github.com/ShineBreaker/nosDshell/commit/d3b10c5977d799835b7db9197fe5f49ae6926f5c)
- pack efficient left zone and honor colorizeIcons defaults：[`39bb6ed9a`](https://github.com/ShineBreaker/nosDshell/commit/39bb6ed9aae00c8ecae49994821a723d02e28f5c)
- split positive into dark/light values for light-shell legibility：[`863493992`](https://github.com/ShineBreaker/nosDshell/commit/863493992c4fb3c3873f4d1d028722ebb687bb80)
- converge efficient-mode indicator on the pill delegates：[`48c6f98df`](https://github.com/ShineBreaker/nosDshell/commit/48c6f98dfeab3f751d30afee96bc3fb7ae943e7e)

### 文档

- rewrite READMEs and repo docs for clarity and product pitch：[`2b946462e`](https://github.com/ShineBreaker/nosDshell/commit/2b946462e4130e5323690d2b4d679e73ee6e4008)

## [1.5.0] - 2026-10-18

这一版补上了两块 DDE 形态下一直缺着的能力：shell 终于自带 polkit 认证代理——需要提权的操作不再静默失败，而是弹出 DDE 风格的认证对话框；插件机制多了一层「内置插件」，随包分发、默认启用、不可卸载——首发成员是停靠栏里的 USB 设备管理器和「概览里直接打字搜索」两个真实痛点。顺带修掉了日历被天气卡片盖住、Wi-Fi 面板首开塌陷又会无界拉长、设置行标签贴着控件三处观感问题。

---

### 新功能

- always-on auth agent with DDE dialog (DESIGN 3.11)：[`f2b839957`](https://github.com/ShineBreaker/nosDshell/commit/f2b83995795238568bec8a911de5f07ef7217756)
- bundle niri-overview-launcher for overview typing：[`1f4b259b2`](https://github.com/ShineBreaker/nosDshell/commit/1f4b259b2452b5694663a4dc8369e2d5258c27b0)
- bundle usb-drive-manager for disk mount management：[`2bc1d9f77`](https://github.com/ShineBreaker/nosDshell/commit/2bc1d9f77ccdfbcc6a46f5c08b962fc964197a9e)
- scan bundled Assets/Plugins as read-only builtin plugins：[`9ec7fbaa6`](https://github.com/ShineBreaker/nosDshell/commit/9ec7fbaa69e20530a28fbe0f0de60a8e6e99f1b2)

### 修复

- re-derive widget lists when plugin widgets register：[`092841235`](https://github.com/ShineBreaker/nosDshell/commit/092841235d3b35d405ec18487c840f1d5031af5b)
- bound popup list viewports, converge scroll sizing：[`bf48f2c78`](https://github.com/ShineBreaker/nosDshell/commit/bf48f2c7834404e1cb557ed916164111556f6ec0)
- one label-to-control gap on field-style rows：[`b94d0e76c`](https://github.com/ShineBreaker/nosDshell/commit/b94d0e76c80853f4811a3f0b3ec8956d8367b08a)
- weather card painted over the month grid：[`c553839e5`](https://github.com/ShineBreaker/nosDshell/commit/c553839e5716baf6766ba994c440bc8f248f0ecc)

### 验证

- pass NIRI_SOCKET to the nested shell：[`ea9ca3399`](https://github.com/ShineBreaker/nosDshell/commit/ea9ca339943e86495d41bc2ba215458aa673a9d0)

## [1.4.0] - 2026-10-18

设置体验做了一次「可读性 + 有用性」的整体大修：重型编辑器搬进二级页、标签筛选常显，每个设置对话框都有「重置为默认值」，右键菜单弹出的设置补上了背景模糊、不再透出底下的窗口内容，当前形态下不生效的控件也不再摆在那里骗人。时尚坞的工作区插件长成了与状态栏一致的胶囊行——索引、占用分色、分组应用视图和逐格切换全部在线；状态栏默认布局则对齐了 macOS 菜单栏的左右分区。

---

### 新功能

- align default status-bar layout with the macOS menu bar：[`698e0ecfe`](https://github.com/ShineBreaker/nosDshell/commit/698e0ecfe38cbe46310f6c4651afe61e47f6dda7)
- reuse bar pill presentation for the fashion Workspace widget：[`3b2ca27c4`](https://github.com/ShineBreaker/nosDshell/commit/3b2ca27c4e6bd1dd26ca6827edccc4824a965743)
- render Workspace fashion cell as clickable mini squares：[`3e1ab34a6`](https://github.com/ShineBreaker/nosDshell/commit/3e1ab34a6d027eaae908ec17d9a8b50acab7152b)
- render Workspace plugin as a fashion tile：[`54e713ef9`](https://github.com/ShineBreaker/nosDshell/commit/54e713ef935fde002335700cdef15fdaaaa4c81e)
- reset-to-default buttons in all settings dialogs：[`081b6088e`](https://github.com/ShineBreaker/nosDshell/commit/081b6088eda3eec747201541e5893eb2522a7a0c)

### 修复

- blur region behind popup dialogs, hide dead workspace controls：[`ba9360e32`](https://github.com/ShineBreaker/nosDshell/commit/ba9360e320097f33367c99093dbffee015b20ffa)
- push heavy editors onto §3.5.3 sub-pages, flatten tag filters：[`ca64c03f7`](https://github.com/ShineBreaker/nosDshell/commit/ca64c03f7c0c46553ad675e6341496035b95e7da)
- manual-schedule row layout + darkman hooks toggle：[`5f72a164e`](https://github.com/ShineBreaker/nosDshell/commit/5f72a164edb0fd4caff40ee7b72fb550360e7cc6)
- publish opaque-body blur region for arrowed popups：[`15dcb4740`](https://github.com/ShineBreaker/nosDshell/commit/15dcb4740b9d002f9d1dbc5b58c0df094dd85b32)

## [1.3.0] - 2026-10-16

深色模式的对外权威面收口了：nosDshell 自带 darkman 兼容的 portal 后端，`darkman get|set|toggle`、GTK4/Electron 的 SettingChanged 订阅和 `~/.local/share/{dark,light}-mode.d/` 钩子目录全部收敛到单个守护进程，根治 darkman 双 daemon 互不同步导致主题跟随时灵时不灵的老毛病。配合颜色方案的「跟随系统」调度与按经纬度的日出日落计时，shell 与桌面应用的明暗从此共用一份权威状态。

---

### 新功能

- add `portal` — single-process darkman-compatible backend：[`49add1552`](https://github.com/ShineBreaker/nosDshell/commit/49add1552c60d4d3fc969038b5d919073bd85633)

### 修复

- parameterize solar timezone so tests are TZ-hermetic：[`b9dadf380`](https://github.com/ShineBreaker/nosDshell/commit/b9dadf380d230ea38d38286e70f99b248f94fe35)
- start portal daemon when helpers resolve before service init：[`f618b71b8`](https://github.com/ShineBreaker/nosDshell/commit/f618b71b8b0ee5d0e9ef3573b336d409de52bff9)

## [1.2.1] - 2026-10-15

一轮以手感与一致性为主题的收敛：niri 下滚轮穿透、遮罩层滚动与面板避让全部修好，滚轮翻页不再丢事件；壁纸、锁屏、卡片与面板的表面全部收进共享令牌，深浅主题切换不再有杂色。

顺手把重复器模型、设置子页条带与搜索索引收敛到一处实现，迁移 82 兜底已盖章的旧配置，删掉失效的壁纸 darkMode 与死垫片。

---

### 修复

- attribute shared settings blocks in the search index：[`a3d4da9a8`](https://github.com/ShineBreaker/nosDshell/commit/a3d4da9a8290fd532d5f1a64579446ca8870ffd0)
- register migration 82 and recover the stamped configs：[`58f0be44c`](https://github.com/ShineBreaker/nosDshell/commit/58f0be44ce7c8e67659329a9fa61a833217c8d37)
- password field reads the wallpaper overlay ladder：[`b3a4925af`](https://github.com/ShineBreaker/nosDshell/commit/b3a4925af6f3720513d4d4b4d954a9af5793b6c0)
- finish edgeClearance migration for remaining setPosition assemblies：[`7bfda79d5`](https://github.com/ShineBreaker/nosDshell/commit/7bfda79d5282cb7ba286dc6d221342021b6383c0)
- compute smart-panel clearance via BarService edge functions：[`a72d8a2d8`](https://github.com/ShineBreaker/nosDshell/commit/a72d8a2d8f5933f5ed4b5feee5822173eba15099)
- set wheel.accepted explicitly at remaining onWheel sites：[`4916daccc`](https://github.com/ShineBreaker/nosDshell/commit/4916dacccf0fad61b5f3ee02001b62abbac81aea)
- use index-based result models in fullscreen and mini views：[`2a2a545af`](https://github.com/ShineBreaker/nosDshell/commit/2a2a545afb6341d1c4b5d1552ab99eb328e1ff95)
- use index-based repeater model for app streams：[`b52939552`](https://github.com/ShineBreaker/nosDshell/commit/b529395526af247d3f4b27325758cc71170bf5d0)
- use index-based repeater models in bluetooth sub-tab：[`3f3e41a1b`](https://github.com/ShineBreaker/nosDshell/commit/3f3e41a1be96792dda0cf81694bf69c72a266fe4)
- decline wheel events explicitly so they propagate under niri：[`7f99675cf`](https://github.com/ShineBreaker/nosDshell/commit/7f99675cff1dd28affe7c1a10210b82b4fb11d39)
- bind real content extent on ScrollView's internal flickable：[`5337c8000`](https://github.com/ShineBreaker/nosDshell/commit/5337c8000372eb553448774f2a11863f357de7b6)
- fold the row gap into the delegate cell：[`49057e4d1`](https://github.com/ShineBreaker/nosDshell/commit/49057e4d1e480253dbc4559030bdeadb3d9f0838)
- wheel scrolling via MouseArea on masked layer surfaces：[`bbff135bb`](https://github.com/ShineBreaker/nosDshell/commit/bbff135bb836c2a51b7c9012b309bdf97a1f0a92)
- dock.launcherIconSize no longer inflates the top-bar capsule：[`ccdf266d1`](https://github.com/ShineBreaker/nosDshell/commit/ccdf266d1ee745fce36e388632215ca9fd10d3f6)

### 观感

- page-surface dropdown plates get a popupPage token：[`a7b3e7dc8`](https://github.com/ShineBreaker/nosDshell/commit/a7b3e7dc81d039ba1597cfe88b5f4b4d17f5140a)
- surfaces on the maskDark glass read overlay levels：[`785baea96`](https://github.com/ShineBreaker/nosDshell/commit/785baea96d244b0267b8e4257290dd27887441c7)
- theme-flipping card plates read constant surface tokens：[`af4e53831`](https://github.com/ShineBreaker/nosDshell/commit/af4e53831590f4ce920ee6c5de54f65a1a2826af)
- scroll fade bands match the maskShell popup glass：[`f7d19a201`](https://github.com/ShineBreaker/nosDshell/commit/f7d19a201cde5febd986d5f4e6119cdf0389a14f)
- band buttons read the wallpaper overlay ladder：[`4df288016`](https://github.com/ShineBreaker/nosDshell/commit/4df28801682eb664c2d3641da17af7ec1156bfc9)
- dim veils read the veilWallpaper token：[`03660d43c`](https://github.com/ShineBreaker/nosDshell/commit/03660d43cfbf04dcb7337822e1b24de65e120a48)
- route default panel background through maskShell：[`d81784348`](https://github.com/ShineBreaker/nosDshell/commit/d81784348ddf962cc38b5612914bdc70602fb3b9)
- on-image veil chips for the strip action buttons：[`052b8662a`](https://github.com/ShineBreaker/nosDshell/commit/052b8662acaf87728ab103553ec48edc2ba64c6a)

### 重构

- migrate remaining sub-tab strips to NSubTabsPane：[`ba4a02ff8`](https://github.com/ShineBreaker/nosDshell/commit/ba4a02ff82e487e4410f2a57d36939eb3a85f0f9)
- drop per-favorite darkMode via migration：[`55460f93d`](https://github.com/ShineBreaker/nosDshell/commit/55460f93de8cf4a7aa3ee77b51ff6310a6ddccba)

### 文档

- usage strings and provenance notes match the binary：[`3b61ead66`](https://github.com/ShineBreaker/nosDshell/commit/3b61ead66ffdb004dde4b4957ccc99724e15dc33)
- align stale comments with the code they describe：[`97d911279`](https://github.com/ShineBreaker/nosDshell/commit/97d9112796357be2e1a978fd3776b00fb1061d37)

### 工程

- drop dead shims and NCheckbox's self-recursive hover signals：[`dfb99c740`](https://github.com/ShineBreaker/nosDshell/commit/dfb99c740766fc9c74d707bdcb1bd37fcde626b8)

## [1.2.0] - 2026-10-14

控制中心重排成 DDE 的样子：默认页是通知列表，卡片成为底部分页条的第一页，模块网格成了"所有设置"的入口页，启动器和各处的设置入口统一落在网格上；快捷开关一页两行十个封顶，溢出页取消。顺手把全 shell 的贴边避让收敛到一个函数——通知、气泡、OSD、菜单和启动器在时尚 dock 上方都不会再被压住。底部分页槽按当前页内容定高，监控卡要显示哪几个表盘可以在设置里挑，整条还能从顶部的把手收起来翻通知。

niri 的模糊规则改成按面分档——之前那种罩住全屏的巨雾没了，模糊只花在真正垫在窗口上的面上。壁纸选择条支持滚轮和两端翻页钮，悬停按钮按浅色/深色槽位标注；启动器按钮的图标、颜色、大小收进一组控件，Dock 与启动器设置页共用，两种模式都能调。通知历史有了日期分节和应用分组，下拉弹层补回阴影与滚动提示，一批标签、日期和文案也顺手现代化了一遍。

---

### 修复

- keep bubbles, OSD, menus and launchers off the dock strip：[`01dec6e09`](https://github.com/ShineBreaker/nosDshell/commit/01dec6e09ce542af2f7a95af3e100d861049044c)
- lift the wallpaper selector strip clear of the fashion dock：[`ede8e44f1`](https://github.com/ShineBreaker/nosDshell/commit/ede8e44f12bf26f99002e313f7fe7093a9e80538)
- notification list interaction and grouping bugs：[`582636b06`](https://github.com/ShineBreaker/nosDshell/commit/582636b06ea4615cde7c09d4c62ece92834628cb)
- import Networking service module in BtDeviceRow：[`57acb5a5b`](https://github.com/ShineBreaker/nosDshell/commit/57acb5a5b984e8bd22f970fa35369dc35436631b)
- locale-correct long dates：[`31732fe0c`](https://github.com/ShineBreaker/nosDshell/commit/31732fe0ce293a3e84b6984580aa8c1b750a8045)
- efficient-mode launcher, menus, pinning and battery pill：[`e21ff1dbc`](https://github.com/ShineBreaker/nosDshell/commit/e21ff1dbce40e79a6912a343180d16876d14d9f1)
- declare mouse param in empty-space click handler：[`f80ac75cb`](https://github.com/ShineBreaker/nosDshell/commit/f80ac75cb06967098ca6c54badf8ea13378a8683)
- top-anchor notification history：[`04c46bc6b`](https://github.com/ShineBreaker/nosDshell/commit/04c46bc6b1be24c2b59b1aeead99e37ba27eab1a)
- NDccRow head/tail scan survives async delegate incubation：[`2c32a14f3`](https://github.com/ShineBreaker/nosDshell/commit/2c32a14f31eeccb338b6bee730e03ed4463b5570)
- combo popups get the shared surface treatment：[`cdb91539f`](https://github.com/ShineBreaker/nosDshell/commit/cdb91539fbd7c27fbd82d84c3f496f0d14b39e32)
- niri layer rules switch to per-surface blur tiers — fixes the fullscreen blur：[`9bb20ada6`](https://github.com/ShineBreaker/nosDshell/commit/9bb20ada68de3e0026594f7b274b851e6d85c5d9)
- filmstrip wheel paging and slot-labelled apply buttons：[`60ec61098`](https://github.com/ShineBreaker/nosDshell/commit/60ec61098835b5203539c1b305dcae2df3a197d6)

### 变更

- notification-first home, module grid as all-settings page：[`b44b8941a`](https://github.com/ShineBreaker/nosDshell/commit/b44b8941a74fd6c5b0f7bdfb69c4378df319ff8a)
- rail highlight follows the scroll live：[`95c37fd6d`](https://github.com/ShineBreaker/nosDshell/commit/95c37fd6d2415c530f703c1e49c2892ca19b4ea0)
- two quick-switch rows, no overflow pages：[`116108cb5`](https://github.com/ShineBreaker/nosDshell/commit/116108cb59fdeff20f220d25d51d9b2e97b09295)
- cards are the quick-control pager's first page：[`dfa3f196b`](https://github.com/ShineBreaker/nosDshell/commit/dfa3f196bfa5e39fa520637d62905444d24e827b)
- selectable gauges on the system monitor card：[`0de3ffa29`](https://github.com/ShineBreaker/nosDshell/commit/0de3ffa2965783dfe0424ec377e0fa2137c6f652)
- quick-control slot sized for the cards page：[`c63f115d6`](https://github.com/ShineBreaker/nosDshell/commit/c63f115d6a2d027680495ce3bad272f621ebabe4)
- compact quick-control strip + collapse handle：[`5aa15985a`](https://github.com/ShineBreaker/nosDshell/commit/5aa15985a6a995d3ca72e9dccc20347ae24b404f)
- display detail page dropped (all controls duplicated), detail pages hug content：[`3374a18b3`](https://github.com/ShineBreaker/nosDshell/commit/3374a18b3fab14a5a9a1148fce33c025ace2ac75)
- collapse chevron pinned to the strip's bottom-right corner：[`9e9aef239`](https://github.com/ShineBreaker/nosDshell/commit/9e9aef23967b790ea9563a67d99aa4aae40a5f7a)
- notification list bottom-anchors to the quick-control strip：[`d108b4193`](https://github.com/ShineBreaker/nosDshell/commit/d108b419336483d54403dd6904b188a77c310b2d)
- anchor the whole notification column — empty state too — and drop phantom zero-height card loaders that ate layout slots：[`b9f4ff125`](https://github.com/ShineBreaker/nosDshell/commit/b9f4ff1259554e18cd0e68aae438063d925b4110), [`f115af00f`](https://github.com/ShineBreaker/nosDshell/commit/f115af00fa508a9a726c353be385d9810a43f5be)
- card toggles hide their actual regions (sliders, switch grid included); strip page order is user-configurable：[`e6e17df42`](https://github.com/ShineBreaker/nosDshell/commit/e6e17df42d6c1cb9f3d0071c186388410b33da57)
- modernised surfaces — labels, row actions, copy and zh terms：[`fd8c2ff25`](https://github.com/ShineBreaker/nosDshell/commit/fd8c2ff25e0f1ea02c002b79b4eb8770ce15b4a5)
- classify pointer/state colour feedback per DESIGN §1.7：[`6267027e2`](https://github.com/ShineBreaker/nosDshell/commit/6267027e20b97fc7b97454aaa85f8d5a45945f9f)
- launcher icon group shared by Dock and Launcher tabs：[`ec7f3bb38`](https://github.com/ShineBreaker/nosDshell/commit/ec7f3bb385e900976e06d61893ea482b4a7caac9)
- NListView scrolls the wheel along its layout axis：[`1e12cf11c`](https://github.com/ShineBreaker/nosDshell/commit/1e12cf11cd7a2f69f3f631899023267f4523bfad)
- launcher icon size slider applies in both dock modes：[`58e511b1d`](https://github.com/ShineBreaker/nosDshell/commit/58e511b1d928d9043e7c41dc286f652a0710287c)
- notification history day sections and app groups：[`f67595ea2`](https://github.com/ShineBreaker/nosDshell/commit/f67595ea2504372f68184e20c58472fa512a433f)

## [1.1.8] - 2026-10-12

一轮针对上游 issue 清单的核验修复：晚到的蓝牙适配器能恢复供电，应用自己调的音量不再被面板值压回，保持唤醒真正拦得住熄屏与锁屏，多屏 Dock 不再丢固定应用，窗口标题刷屏时任务栏图标也不再闪烁。顺手把三处复制的桌面项启动路径和三处工作区标签写法各收敛成了一处。

---

### 修复

- stop taskbar/workspace icons blinking on window title churn：[`e40af9958`](https://github.com/ShineBreaker/nosDshell/commit/e40af9958f29d935ca95b4b8ea8c5c36e3203534)
- elide long titles in media player without buttons：[`2df2969b5`](https://github.com/ShineBreaker/nosDshell/commit/2df2969b5e894666c998eca33456bf8dd0cf0947)
- keep pinned apps on other outputs with onlySameOutput：[`cd416d9d7`](https://github.com/ShineBreaker/nosDshell/commit/cd416d9d73e3b62c910a3808571a2ab6b24e80a5)
- let Keep Awake suppress the shell's own idle actions：[`e51ef83ed`](https://github.com/ShineBreaker/nosDshell/commit/e51ef83edb147961c703fa57780ce80607f260b5)
- stop sticky per-app volume from overriding the app itself：[`e4a85e34a`](https://github.com/ShineBreaker/nosDshell/commit/e4a85e34ab73225579af414ecd3d03b172794b67)
- re-sync adapter power when the adapter appears late：[`b20d25a47`](https://github.com/ShineBreaker/nosDshell/commit/b20d25a472f45da1bfc90a26ed1c35417e128796)

### 重构

- drop the dead search-focus hook from LauncherModel：[`04d3a9687`](https://github.com/ShineBreaker/nosDshell/commit/04d3a96877a328bf9d4a55e4d49d0255d7e8eb33)
- derive workspace label text in one place：[`4b2b2247f`](https://github.com/ShineBreaker/nosDshell/commit/4b2b2247f1bc0111beb00fbadd2a41ac061a8201)
- one launch path for desktop entries：[`e2dd5f151`](https://github.com/ShineBreaker/nosDshell/commit/e2dd5f15189d5f4b0b4fd72ccf9df9d3c44d3615)

## [1.1.7] - 2026-10-12

一次设置体系的整体审计与收口：每个声明过的键都有了读者、读者或归宿，设置页补上了缺失的控件，壁纸面板找回了纯色与收藏入口；悬浮从栏形态里独立出来，简约/边框两种形态都能叠加；凹槽线、行高、字号、空态图标这些散落在各处的字面量全部收进了令牌；配套的检查器护栏会让同类退化在 lint 阶段就被拦下。

---

### 新功能

- `nosdshell --version` 显示 shell 与 quickshell 版本（Guix 构建附带 fork commit）
- bash/zsh/fish 终端补全（`completions/`），随 Guix/Nix 包安装到标准目录
- add controls for appLauncher.displayMode and ethernetDetailsViewMode：[`7a595d4e6`](https://github.com/ShineBreaker/nosDshell/commit/7a595d4e65ce4b933660561b99c71873a572efe4)

### 修复

- restore solid-color and favorite entry points：[`577c5ec62`](https://github.com/ShineBreaker/nosDshell/commit/577c5ec62d71dd72a686f7913a6c2f971c98e238)
- clean up keys removed in d3f2097f2：[`1fedcd52b`](https://github.com/ShineBreaker/nosDshell/commit/1fedcd52bf321debcbaadaf6e5629673b24f8e92)
- read seed settingsVersion from Settings.qml：[`2b24dd57e`](https://github.com/ShineBreaker/nosDshell/commit/2b24dd57e2481b7cdfa1aab717f652182150ff79)
- sync settingsVersion and assert it in check-settings-keys：[`65d70c014`](https://github.com/ShineBreaker/nosDshell/commit/65d70c014a71e22eefcb6801e8f0ba2c24bb00a3)

### 观感

- add missing tokens for tray/lock/cc/empty-state：[`11a33415d`](https://github.com/ShineBreaker/nosDshell/commit/11a33415d3c67d0e1dee68bf710e6119c517539c)

### 重构

- add NDivider variant for DDE groove separators：[`e0f5f2ef3`](https://github.com/ShineBreaker/nosDshell/commit/e0f5f2ef320d51fa48bdccff5821bdd92094a613)
- remove ?? fallbacks on declared settings keys：[`25227fef3`](https://github.com/ShineBreaker/nosDshell/commit/25227fef385d5065e04382026482d97b93593888)
- make floating an independent bar option (v81)：[`94b17c78d`](https://github.com/ShineBreaker/nosDshell/commit/94b17c78d19c795ef8939b1ce14336f271a7606a)

### 文档

- dedupe provenance rule and fix README scope：[`21aa1d511`](https://github.com/ShineBreaker/nosDshell/commit/21aa1d511f867ba46c370570e5ff9dc34675d5cb)
- complete §6.1 removal registry：[`4b1303670`](https://github.com/ShineBreaker/nosDshell/commit/4b1303670645253eddd6beaf2edbfccf1e3e1d80)
- mark compat/unexposed keys at declaration and DESIGN §6：[`d70979951`](https://github.com/ShineBreaker/nosDshell/commit/d70979951e610b44238b3c3151f7062c90016376)
- regenerate for bar.rightClick*; lint guards the key set：[`388dfb590`](https://github.com/ShineBreaker/nosDshell/commit/388dfb590b3706ff31850615679cd11aedd7ec4e)

### 工程

- guard orphaned entry points and control-to-key refs：[`8d8e3ae64`](https://github.com/ShineBreaker/nosDshell/commit/8d8e3ae64aba498129a7ce34d2edba4536c76c1d)

## [1.1.6] - 2026-10-12

状态栏的可定制项补全了：形态（简约/悬浮/边框）、非独占显示模式、工作区切换时唤出、空白处右键动作（含自定义命令和跟随光标）都回到了设置页；老配置里残留的右键设置会被保留。

---

### 新功能

- restore upstream status-bar customization surface：[`f083f3dee`](https://github.com/ShineBreaker/nosDshell/commit/f083f3deebe22920bf9b75eda1385afb3974dda4)

### 修复

- install python in the qmllint container：[`b503a8902`](https://github.com/ShineBreaker/nosDshell/commit/b503a89024f4c65535bcf2be4b1b141872ffeefb)

### 文档

- regenerate settings reference for v1.1.5：[`0c5cb0c9b`](https://github.com/ShineBreaker/nosDshell/commit/0c5cb0c9bdfdeefabcb35bd6ce4a1857c790dfa4)

## [1.1.5] - 2026-10-11

一轮动效与稳定性的整体打磨：右键菜单、小组件弹层和全部下拉框、对话框补上了统一的淡入滑出动效，关闭弹层后偶发残留的模糊色块一并清除；通知图标在加高的气泡里垂直居中、气泡阴影不再偶发变形；还修掉了一类偶发崩溃——窗口或设备恰好在列表刷新的间隙被销毁时，dock、媒体、蓝牙、托盘、音频、电池等列表都可能踩到，这次统一收口。通用设置页正式接入 DDE 各视图，dock 设置按功能分组并可给插件条加间距、拼成时尚一体的胶囊。

---

### 新功能

- fade and slide popups, menus and tooltips on popup motion tokens：[`ee4c08d10`](https://github.com/ShineBreaker/nosDshell/commit/ee4c08d10587ca23dce1b539517067cecfff73c1)
- consistency checkers for settings keys and translations：[`46c9e6f82`](https://github.com/ShineBreaker/nosDshell/commit/46c9e6f8242e1e834d7e47414c9fa5f413c8f8f6)
- regroup the dock page by feature and hide what its switch disables：[`bbcf8c852`](https://github.com/ShineBreaker/nosDshell/commit/bbcf8c852366bcba1797d75967f2a4c1051d640e)
- plugin strip spacing knob + optional fused pill (fashion)：[`2f1c04513`](https://github.com/ShineBreaker/nosDshell/commit/2f1c04513242990d7bd05b364cf949035d1aed58)
- wire general settings into the DDE views, drop overlay frontend：[`390d8de79`](https://github.com/ShineBreaker/nosDshell/commit/390d8de7937def9d611ee8047873374767534f64)

### 修复

- keep service-owned QObjects out of remaining delegate models：[`db0b4f582`](https://github.com/ShineBreaker/nosDshell/commit/db0b4f582f6c28000221ab4b2c21d5b71cc22151)
- never nest NDropShadow inside its source; center bubble icon：[`559660a19`](https://github.com/ShineBreaker/nosDshell/commit/559660a19041a69c1a8ccd9a2c9945c3cdb331a5)
- keep Toplevel refs out of the app Repeater's delegate model：[`4f3563d8a`](https://github.com/ShineBreaker/nosDshell/commit/4f3563d8a22fc7244b9dacd927fe07a82f4bcdf4)
- re-send settled surface regions to dodge niri's blur cache race：[`11073ca12`](https://github.com/ShineBreaker/nosDshell/commit/11073ca12ec6ef53e2b2734ae9d84df31a5b8d0e)
- skip open watchdog for zero-frame popups：[`6ee22258a`](https://github.com/ShineBreaker/nosDshell/commit/6ee22258a4f9b2a4efa27a9948505a870b4c8af3)
- ride zero-frame popup cleanup on the hide commit：[`2d9ad9e95`](https://github.com/ShineBreaker/nosDshell/commit/2d9ad9e95e98b67ac1a7a23e575f2bcb7b145538)
- force pending blur-region commits on stock quickshell：[`97847f810`](https://github.com/ShineBreaker/nosDshell/commit/97847f810bb588d1e9c9b536939f2d3116cde404)
- commit blur region swaps so stale bands can't ghost：[`1af3caf9e`](https://github.com/ShineBreaker/nosDshell/commit/1af3caf9e91210b9f2653e928a9c5fab95b2e228)
- anchor popups and edge sheets to their host surface edge：[`2716aacda`](https://github.com/ShineBreaker/nosDshell/commit/2716aacda85850e14e6a5f1937dea099a7abff18)
- track animated bubble rects in notification and toast masks：[`ce27217c5`](https://github.com/ShineBreaker/nosDshell/commit/ce27217c584a8bf14c8a7625b157057c0c55aab4)
- keep resolvable clauses of compound visibleWhen in search index：[`2af064177`](https://github.com/ShineBreaker/nosDshell/commit/2af064177b972c225ba8d3891422e4533453ab81)
- wire strings to I18n.tr and drop unreferenced keys：[`f9f26f83a`](https://github.com/ShineBreaker/nosDshell/commit/f9f26f83a9391a4f89b6f30ee324908950addb5d)
- drop dead Noctalia layout keys via v78 migration：[`5fbffb3ce`](https://github.com/ShineBreaker/nosDshell/commit/5fbffb3ce42a7f4be14ad2f4b491857c4fea7b0a)
- center collapsed pill icons in their tile and normalize fashion cell padding：[`69713bc2c`](https://github.com/ShineBreaker/nosDshell/commit/69713bc2c05e92fc7754cd842f826417d27fa5b2)
- measure the real plugin area and restore the fashion clock's full item slot：[`e4a1db595`](https://github.com/ShineBreaker/nosDshell/commit/e4a1db595f396bd418874256f87175cb3c7b94f4)
- uniform dockPresentation interface and fashion tiles for every plugin：[`41bf38c2c`](https://github.com/ShineBreaker/nosDshell/commit/41bf38c2cc14858986af34777a86e0d6696a1b1f)
- detach launcher blur regions while their windows are hidden：[`c320aa9e2`](https://github.com/ShineBreaker/nosDshell/commit/c320aa9e2e2e134f19b675290a77503ccce18060)
- settings context menu follows the shell theme：[`05da309d8`](https://github.com/ShineBreaker/nosDshell/commit/05da309d8cff787b491b53592571a825d21d17e0)
- apply dock.deadOpacity to pinned apps in the taskbar widget：[`9f61def00`](https://github.com/ShineBreaker/nosDshell/commit/9f61def0099acf057a7fb73630c314c41f9af224)
- clearSearchOnClose now actually preserves text on reopen：[`bb5cf532c`](https://github.com/ShineBreaker/nosDshell/commit/bb5cf532c1fc6e95bc844da2865b273af6f39b69)

### 文档

- drop unverifiable plug-icon attribution：[`b80cc1a2f`](https://github.com/ShineBreaker/nosDshell/commit/b80cc1a2ff641e081859ec5e61bf1a438e0ca818)
- plain prose, one source per value, stale rules corrected：[`0b9042793`](https://github.com/ShineBreaker/nosDshell/commit/0b90427939dfa08161fd25a83055f09ed28fed9d)
- regroup by layer, migration recipes, general QML rules：[`157fa3f4d`](https://github.com/ShineBreaker/nosDshell/commit/157fa3f4d956df6bda802d9caebee2546311c48f)
- name the layer each fix belongs to：[`670fb8103`](https://github.com/ShineBreaker/nosDshell/commit/670fb8103148499c099da3ecb69f14f5abe9048a)
- plain, checked descriptions in README and CREDITS：[`e370d59e7`](https://github.com/ShineBreaker/nosDshell/commit/e370d59e78b51774fa458f125c980725362fdd48)
- plain prose and current facts in the auxiliary docs：[`afc6e35c1`](https://github.com/ShineBreaker/nosDshell/commit/afc6e35c126c8f5b54ff9224269d1bc3390147fc)
- root-cause working method and one source per rule：[`c26c0b865`](https://github.com/ShineBreaker/nosDshell/commit/c26c0b8653891b1874d666cbcbeb84703c419f0e)
- global-token integration + settings↔frontend parity：[`d953b6f1f`](https://github.com/ShineBreaker/nosDshell/commit/d953b6f1f115bf197ab5383ccc8e6231a3acf0a2)

### 其他

- just task runner + automated release script：[`4e5513a20`](https://github.com/ShineBreaker/nosDshell/commit/4e5513a20416adf4bee5c56cba366e619a66ede7)

## [1.1.1] - 2026-10-10

一轮观感抛光，顺带补了两项功能：深色模式可以跟随系统切换，电池挂上充电绿/低电红并支持滚轮调亮度；dock 小弹层不再压暗全屏，悬浮阴影的半透明黑块、下拉菜单透出页面文字、右键菜单省略文字这批毛边一并修平。

---

### 新功能

- 深色模式计划新增"跟随系统"，走 freedesktop portal 外观偏好：[`f23fc3de1`](https://github.com/ShineBreaker/nosDshell/commit/f23fc3de1efa349ef0561a7c4ba058ed6ba07b0c)
- 电池挂件按充电（绿）/低电量（红，阈值可调）着色；滚轮调亮度从电源键移到电池：[`c12e4fb6f`](https://github.com/ShineBreaker/nosDshell/commit/c12e4fb6fa47bc406b3c5d741e2d582f0fbedc45) [`c8df3851b`](https://github.com/ShineBreaker/nosDshell/commit/c8df3851bc7d80648c74841fcbdf0d03b4fe27d0)

### 观感修复

- dock 快弹面板不再触发全屏压暗：[`ca7e3ce94`](https://github.com/ShineBreaker/nosDshell/commit/ca7e3ce9482f1af3fe70da82ff403d13c5add88e)
- 悬浮控件阴影的半透明高原区 alpha 减半：[`10f7255a6`](https://github.com/ShineBreaker/nosDshell/commit/10f7255a63e59345fd49ab9cd6055890b1b80eb1)
- 壁纸压暗层固定纯黑，不再随主题染色：[`e592c5429`](https://github.com/ShineBreaker/nosDshell/commit/e592c54293c187ef3bfb066e592b33834098527f)
- 设置页下拉弹层改不透明底，菜单 accent 高亮块加 `radiusRow` 圆角：[`32979f75f`](https://github.com/ShineBreaker/nosDshell/commit/32979f75f970947e168c6d4e69cfa7cbc6a1f53b) [`f3aa14b1d`](https://github.com/ShineBreaker/nosDshell/commit/f3aa14b1de19d7b20080223875d592ff6c809245)
- 右键菜单宽度计入行内边距，短标签不再省略：[`3e1da7312`](https://github.com/ShineBreaker/nosDshell/commit/3e1da73125aa0dc3a299152f2b1bdc00512e6291)
- 勿扰通知的分组续行缩进恢复：[`590209e96`](https://github.com/ShineBreaker/nosDshell/commit/590209e96a4d7f55617764b02bbe1dd3350cec46)

### 设置修复

- 蓝牙/账户等模块页只渲染自己拥有的设置组：[`90228f713`](https://github.com/ShineBreaker/nosDshell/commit/90228f713cdc6772d27e1f3c0f5baee5107fa166)
- 配色方案卡栅格高度塌陷修复：[`ec1e4ec5e`](https://github.com/ShineBreaker/nosDshell/commit/ec1e4ec5e862535bcf56a19f666688a922560aad)

### 工程

- CI 增加 qmllint / 脚本 / 文档同步检查，tag 自动发版：[`90e456816`](https://github.com/ShineBreaker/nosDshell/commit/90e4568162732ca3acdc2d99bb22a7ff9db18c9d)
- README 双语化，Pages 挂载 Noctalia v4 wiki 存档镜像：[`6afbd7252`](https://github.com/ShineBreaker/nosDshell/commit/6afbd72522ca587cb57d3cbb7b73279323e61f01)
- 验证场景新增 settings-combo、dock-context-menu 等：[`05c7578c9`](https://github.com/ShineBreaker/nosDshell/commit/05c7578c994898abf071da0a6459a8088b8b22c3) [`22cb82894`](https://github.com/ShineBreaker/nosDshell/commit/22cb8289418dccfda0bbab3c7abb5a7279e9efcb)

## [1.1.0] - 2026-10-10

主题令牌体系补齐 + 全局白色图标自适应，另有一轮启动器/控制中心修复、性能与重构。

### 主题与图标

- 新增 `Color.onWallpaper` 令牌族（壁纸面恒白前景/叠加层/投影，DESIGN §1.5），壁纸面统一改用它，`onShell`/`overlay()` 在壁纸面禁用。
- 瞬时面（OSD/通知/吐司）整体主题化：`maskTransient` 令牌族 + light/dark 形态与 `ui.transientOpacity` 调节旋钮。
- 表面角色改走配色方案路由（MD3/Noctalia 染色），`accentOverride` 解析到 `m*` 角色层；剩余硬编码颜色全部替换为令牌；亮色模式 `onShell` 弱化层对比度提高。
- 烘焙成白色的 DDE 素材（设置导航、控制中心宫格与铃铛、mini 启动器右栏全套）按面重着色为 `onShell`——亮色面深色、暗色面白色；壁纸面按规范保持白色。
- freedesktop `*-symbolic` 图标按约定染为面墨：通知气泡/历史、mini/全屏/覆盖启动器应用图标、音频面板、图标预览全链路（`ThemeIcons.isSymbolicPath` + `NSymbolicImage.detectSymbolic` + `NImageRounded.symbolicColor`）；彩色图标与照片内容不受影响。

### 启动器

- mini 启动器两级分类列表（重分类点击回 "全部"）、时钟日期不省略、描边收敛为 1 px 发丝。
- 壁纸/空白处点击关闭、点击项直接激活而非旧选中、关闭时可选清空搜索框、打开设置/关机菜单前先关启动器。
- 全屏启动器亮色模式可读性修复；合成器提供模糊时保留 0.55 压暗层（壁纸面保持暗色，§1.5）。
- `LauncherCore` 状态管线并入内嵌 `LauncherModel`；网格右键菜单懒实例化。

### 控制中心与通知

- 页指示点主题化；快捷控制页几何统一并支持滑入分页；滑条恢复跟手；修复 switch 页 1 重复行与分页 chevron/wheel 的 TypeError。
- 边缘 scrim 改为局部阴影带并可按部分调节；通知历史列表虚拟化。
- `NotificationServer` 不再随每次设置保存重建（`org.freedesktop.Notifications` 自竞态）；溢出驱逐改为先删行后 `dismiss()`，修复快速通知间隔一条不弹的问题。

### Dock / 任务栏 / 其他修复

- 时尚托盘胶囊与电池按面令牌渲染；blur/mask region 跟踪重构（`NSurfaceRegion`）；全屏覆盖时释放 strip 输入区。
- "dock" 挂件设置写路由修复（此前静默丢弃）；工作区按屏过滤与 appId 匹配提取为共享件。
- OSD 显示期间再次触发就地刷新数值，不再重播弹出动画（对齐上游）。
- 位置服务无坐标告警每周期一次；蓝牙 discoverable/scanning 乒乓停止；SNI 模型冗余重写合并。
- 锁屏倒计时与快捷键说明在亮色模式保持白色。

### 性能与重构

- keep-alive 面板隐藏期预热；列表边缘按真实表面淡出到无（玻璃面统一）。
- 设置页折叠出 `NDisplayModeComboBox`、`NSubTabsPane`、`IconColorSettings`、`WidgetSettingsHelper` 等共享件；高级溢出页按对象重排；会话电源动作统一 `SessionActions`。
- 合成器 blur region 隐藏时分离；`debug` IPC 增加场景坐标与属性 setter 取证能力。

### 工具与打包

- `quickshell-nosd` 改为我们的 fork `ShineBreaker/quickshell-nosd`（上游 0.3.2 + 两个 pipewire UAF 修复 commit），原 `packaging/patches/` 本地补丁随之移除。
- `Scripts/test/bench.sh` 隔离性能基线；`verify.sh` 新增 cc-slider/launcher-dismiss/category/dock-widget-menu/notification-resave/notification-icon 等场景；`vinput` extent 参数解析修复。
- `DESIGN.md` 增补现代化演绎层说明（结构忠于 DDE 15，渲染层按现代惯例精修）。

## [1.0.2] - 2026-10-08

动效按 DDE 15 规范全面打磨并补充设计规范，另修复启动器崩溃与设置页滚动的两个结构性问题。

### 动效规范与实现

- `DESIGN.md` 新增三层动效规范（瞬变清单、曲线词汇表、不对称退场），`Commons/Style.qml` 补齐 DDE 节拍令牌；全部数值可溯源到 GXDE-OS 源码行号。
- 违禁曲线清零：`OutBack`/`OutInBounce`/`BezierSpline`/无效 overshoot 全部换成规范词汇。
- tooltip、菜单、箭头弹层显隐改为瞬变；22 处指针态颜色/透明度渐变瞬变化（对齐 DDE 即时重绘）。
- OSD：进入 160 ms `OutCubic` 淡入 + 上移 12 px，退出 120 ms `InCubic` 下移 8 px；数值条直跳不补间。
- 通知气泡：进入 180 ms 沿锚定边水平滑入 12 px，退出 300 ms `OutCubic`；错峰延迟的外漂修正。
- Toast 入/出拆分 180/300 ms；面板与遮罩退场统一 `InCubic`。
- 滚轮惯性 800 ms `OutQuint` 与程序化滚动 300 ms `OutQuad` 分开驱动。
- dock 提醒摆动按 `appswingeffectbuilder.h` 帧表重做（±8° 阻尼 + 18 px 抬升，约 2.2 s 一轮）。
- 控制中心 home↔模块页切恢复水平滑动（几何 Behavior 误挂换肤守卫修复）。
- 启动器：底框与内容统一进可动画面，mini 8 px 位移真正生效，黑幕/遮罩随面板透明度渐变；壁纸默认过渡对齐 DDE 约 1 s。

### 修复

- 启动器快速切换模式时偶发 `QQmlIncubator` 崩溃：委托孵化窗口内的服务回调用 `Qt.callLater` 移出孵化窗口，搜索结果模型每键入两次全量重置改为单次赋值。
- 设置页从启动器/IPC 打开时直跳目标模块（此前 1400 ms 从头滚到尾，懒加载期间看似卡住）；滚动动画只保留给 rail 点击与键盘翻页。
- dock 图标静止时倾斜 8°：摆动相位公式在 `swingPhase=0` 处读出 8°，旋转改为仅在摆动动画运行时生效。
- 长时间运行后偶发 `QQmlIncubator` 崩溃：toplevel/SNI 信号突发期间 `dockApps` 全量重赋值重入 Repeater 委托孵化；重建合并到事件循环单回合执行，且应用序/类型/置顶态/toplevel 集合不变时跳过赋值。
- 窗口全屏时该输出的任务栏/dock 自动隐藏（不留感应条、悬停不唤出），退出即恢复；niri 端经 ext-foreign-toplevel 关联窗口判定全屏，`DESIGN.md` §3.1 已记录语义。

## [1.0.1] - 2026-10-08

设置页 DDE 化收尾与一轮 Noctalia 业务逻辑保真审计整改：所有设置项统一行样式，几处在改造中丢失或断线的上游能力全部接回。

### 设置界面

- 统一行样式：裸行全部换成 `NDccRow`（设备单选、通知规则、自定义空闲命令、钩子、空闲状态、启动器图标、颜色选择行），同组行合并为一张卡、1 px 缝、首尾圆角自动推断。
- 标题列加宽度下限，"一周的第一天"等长标签不再折行；`NComboBox` 默认字段宽收窄。
- 快捷键录制器修复：已绑按键恢复显示，胶囊等分宽度、空槽改居中图标、清除按钮改为悬停显现。
- 消除 `NTabView.stacked` 下的重复组头；堆叠组间距统一。
- 高级设置拆分为任务栏 / 状态栏 / 显示器 / 面板与圆角四个堆叠组（复用每屏覆盖页，配置键零丢失）。
- 配色模板列表改为自适应多列网格；Toast、取色器、时间日期令牌等弹层统一到 transient/overlay 令牌。
- `settings openTab` 支持子页直达（`tab/sub` 路由兜底），`verify.sh` 新增 `settings-<tab>/<sub>` 与 `settings-scroll-*` 截图场景。

### 业务逻辑保真

- 恢复在线配色方案下载（`SchemeDownloader` + `ShellState` 方案缓存）。
- 恢复状态栏挂件编辑器：全局编辑器接入任务栏页，每屏覆盖页恢复位置/密度/显示模式/挂件编辑。
- 恢复通知历史键盘导航（Tab/方向键/Enter/Delete，动作项高亮）。
- IPC 修正：`openTab bar` 路由到任务栏页，`non_exclusive` 写回 `bar.displayMode`，启动器搜索透传不再被吞。
- vicinae 模板指向现存的 `nosdshell.svg`；迁移器不再产生孤儿设置键。
- Rust 工具（`nosd-theme`/`nosd-helpers`/`nosd-blur`）探测链回退 `target/debug`——开发机上非 release 构建不再让着色/输入注入静默失效。
- 确认有意移除项（更新检查、Changelog、遥测/赞助服务）并在 `DESIGN.md` §6.1 记录理由；关于页注明"更新由系统包管理器统一分发"。

## [1.0] - 2026-10-07

首个正式版本，也是仓库的第一个 tag（此前本地、远端均无任何 tag）。
nosDshell 基于 Noctalia v4（Quickshell/QML），保留其全部功能，以 DDE 15 的视觉语言重做每个界面；全部尺寸、透明度与动效时长取自 GXDE-OS 源码，规范见 `DESIGN.md`。

### 界面

- 统一任务栏：高效模式（通栏）与时尚模式（悬浮 dock），四个停靠方向；弹出层为锚定图标的带箭头矩形气泡。
- 启动器：DDE 风格全屏启动器（模糊壁纸背景，任务栏保持可交互）与迷你启动器；应用 / 命令 / 计算搜索与分类浏览。
- 控制中心：408 px 右缘框架，全屏毛玻璃；15 模块宫格、快捷开关分页与通知历史；设置页默认内嵌。
- 会话菜单：居中一排 140×140 按钮（关机 / 重启 / 挂起 / 休眠 / 锁屏 / 退出登录），默认选中锁屏，带数字键提示。
- OSD：底部居中 140×140 浅色气泡，覆盖音量、亮度与过载状态。
- 通知与 Toast：300 px 气泡逐条排队，DDE 风格动作按钮。
- 锁屏：底部信息带（时钟、日期、媒体与电源控制）+ 居中认证区。

### 继承自 Noctalia 的能力

- Niri / Hyprland / Sway / Scroll / Labwc / MangoWC 多合成器支持，多显示器、壁纸管理、桌面挂件、插件体系、设置迁移。

### 工具与打包

- Rust 工具：`nosd-blur`（壁纸预模糊）、`nosd-helpers`（单二进制多子命令）、`nosd-theme`（Material 主题处理）。
- Guix 打包（`nosdshell.scm`）与 Nix flake（含 home-manager / NixOS 模块）。
- 运行在上游 Quickshell 0.3.1，另带两个 pipewire UAF 补丁（`packaging/patches/`）。

[Unreleased]: https://github.com/ShineBreaker/nosDshell/compare/v1.6.3...HEAD
[1.6.3]: https://github.com/ShineBreaker/nosDshell/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/ShineBreaker/nosDshell/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.8...v1.2.0
[1.1.8]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.7...v1.1.8
[1.1.7]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.6...v1.1.7
[1.1.6]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.5...v1.1.6
[1.1.5]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.1...v1.1.5
[1.1.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ShineBreaker/nosDshell/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/ShineBreaker/nosDshell/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/ShineBreaker/nosDshell/compare/v1.0...v1.0.1
[1.0]: https://github.com/ShineBreaker/nosDshell/releases/tag/v1.0
