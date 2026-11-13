# 打包与发布链路核对清单（阶段 4 Reviewer 审查产物）

> 审查日期：2026-11-13｜审查人：Reviewer｜审查基线：`nosd-theme` @ `e7bfcc0`、`nosDshell` @ `6c0b4ba55`
> 对照：PLAN-app-theme-unification.md §6.5「打包与发布」+ 群任务书增量项

## 一、PLAN §6.5 逐条对照

| PLAN §6.5 要求 | 现状 | 证据 | 判定 |
|---|---|---|---|
| GitHub Release：tag 触发 CI | `.github/workflows/release.yml` `on.push.tags: ["*"]` + `workflow_dispatch` | release.yml:9-12 | ✅ |
| 产出 deb | `dpkg-buildpackage -b`（job `build`） | release.yml:31-36 | ⚠️ `|| true` 吞失败 |
| 产出 rpm | **无 CI 步骤**；`rpm/nosd-theme.spec` 存在但未被任何流程调用 | `ls rpm/` + release.yml 无 rpmbuild | 🔴 缺项 |
| 产出 tar.gz | `tar --exclude-vcs -czf dist/nosd-theme-$VERSION.tar.gz` | release.yml:24-28 | ✅ |
| AUR：复用 `arch/PKGBUILD`，包名 `nosd-theme-git` | `pkgname=nosd-theme-git`、`url=github.com/nosDshell/nosd-theme` | PKGBUILD:2,6 | ✅ |
| 包内容：GTK + Kvantum 各一目录 | Makefile `install-gtk`（deepin + deepin-dark → share/themes）、`install-kvantum`（nosd → share/Kvantum） | Makefile:6-13 | ✅ |
| 安装路径：GTK→/usr/share/themes/、Kvantum→/usr/share/Kvantum/ | `PREFIX=/usr` 默认，两处 cp 落位正确 | Makefile:1,8,12 | ✅ |
| 图标拆成子包（可选） | 无 `icons/`、无子包拆分——范围外（步骤 9 已排除），PLAN 原文即「可选」 | 群范围钉死 | ✅ N/A |

## 二、增量项核对（阶段 3 产物进包）

| 项 | 要求 | 现状 | 判定 |
|---|---|---|---|
| 4 个 `nosd-accent.css` 占位进包 | tar/deb/包 都带上 | `find` 实列 4 个在 `deepin{,-dark}/{cinnamon,gnome-shell}/`；tarball 实构建含 4 个（`deepin/cinnamon/nosd-accent.css` 等）；Makefile 整目录 `cp -r` 自动带入 | ✅ |
| `@import url("nosd-accent.css")` 4 行在包内 | 主题 css 末尾 | 4 文件 `grep -l` 全命中 | ✅ |
| `make install-user` 目标 | 落 `~/.local/share/themes` | `install-user: $(MAKE) install PREFIX=$(HOME)/.local`——语义正确：`PREFIX=~/.local` + `share/themes` = `~/.local/share/themes` ✅ | ✅ |
| cinnamon/gnome-shell 无 `@` 颜色引用进包 | checker 规则兜底 | checker 新增 St 规则已反证（@xxx 必报），`make check` 0 告警 | ✅ |

## 三、一致性问题清单（按严重度）

### 🔴 必修

1. **rpm 产物 PLAN 要求、CI 未产出**
   - PLAN §6.5 明文「tag 触发 CI，产出 deb / rpm / tar.gz」；`release.yml` 只有 deb + tar.gz，`rpm/nosd-theme.spec` 从未被 CI 调用。
   - 修法：加 `rpmbuild` 步骤（`sudo apt-get install -y rpm` 或换 fedora 容器镜像跑 `rpmbuild -ba`），产物 `*.rpm` 进 `dist/`；或在 PLAN 里把 rpm 删掉——**别让 PLAN 与 CI 不一致**。

2. **`dpkg-buildpackage ... || true` 会静默放行构建失败**
   - release.yml:34-35 `dpkg-buildpackage -us -uc -b || true` 与 `ls ../*.deb && cp ... || true` 双重吞错：构建失败时 job 显示绿色、Release 仍发布 tar.gz 但 deb 缺席且无报错。
   - 修法：去掉 `|| true`，让 `set -eu` 生效；deb 产不出就该红。

### 🟡 建议

3. **版本号三处口径统一但缺自动同步**
   - `debian/changelog` `0.1.0-1`、`PKGBUILD pkgver=0.1.0`、spec `Version: 0.1.0` 当前一致 ✅；但 tag 推 `v0.2.0` 时只有 `dch -v` 动 debian/changelog（CI 内），PKGBUILD 与 spec 不会自动跟。
   - 修法：release.yml 里加一步 `sed -i` 同步 pkgver/spec Version，或接受「pkgver 只在本地 PKGBUILD 起作用，AUR 靠 pkgver() 函数」——建议给 PKGBUILD 加 `pkgver()` 用 `git describe` 动态取。

4. **PKGBUILD 缺 `pkgver()` 函数**
   - `-git` 后缀包的惯例是 `pkgver()` 返回 `git describe` 动态版本；现在写死 `0.1.0`，AUR 场景每次 tag 都要手改。
   - 修法：`pkgver() { git describe --tags --long | sed 's/^v//;s/-/./g' }`。

5. **`install-user` 依赖 `$(HOME)`，打包环境可能为空**
   - `PREFIX=$(HOME)/.local` 在 `makepkg`/`dpkg` 构建环境里 HOME 可能不是目标用户目录；但 `install-user` 本来就不是给打包用的（打包走 `install`+`PREFIX`），仅手写场景。文档里注明即可，非 bug。

### 🟢 记录

6. 占位 `nosd-accent.css` 的注释说「不要手工加规则」——checker 的 St 规则会真拦（`@xxx` 在 cinnamon/gnome-shell 报错），闭环成立。
7. `nosd-theme.spec` `%make_install PREFIX=%{_prefix}` 与 Makefile `DESTDIR=$(DESTDIR)$(PREFIX)` 组合正确（DESTDIR 前缀 + /usr），`%files` 三段与 install 目标对应。

## 四、结论

- **判定**：CONDITIONAL PASS——PLAN 主体达成，rpm 缺项与 `|| true` 吞错两处修完即可 PASS。
- **CSD messagedialog 合成器截图**：容器内无 X/合成器/桌面会话（`ls /tmp/.X11-unix` 空、`which picom xfwm4` 空），环境阻塞维持，留待真机窗口。

## 五、Worker `7ec71d3` 修复后的复验（2026-11-13 补记）

Worker 修了 rpm 缺项、`|| true`、tar 污染三处。复核后剩余：

| 项 | 状态 | 证据 |
|---|---|---|
| `git archive` 替代 tar | ✅ 已修 | `git archive HEAD \| tar -t` 含 4 个 nosd-accent.css、`arch/pkg` 0 条 |
| `|| true` 吞错 | ✅ 已修 | `dpkg-buildpackage` 裸奔，失败会红 |
| rpm 步骤补齐 | ⚠️ 框架对、版本传值错 | `--define "version"` 不覆盖 spec 字面量 `Version:`，实测仍按 0.1.0 找源码包 |
| **`debhelper` 未装** | 🔴 CI 必炸 | `debian/control` `Build-Depends: debhelper (>= 9)` vs release.yml 装包清单无它 |
| **rpm 版本不同步** | 🔴 非 0.1.0 tag 必炸 | spec `Version: 0.1.0` 字面量，需 `sed` 同步 |

修正后结论：**CONDITIONAL PASS → 待两处 🔴 修复后 PASS**

## 六、终审 `a5a623e`（2026-11-13 收口）

两处 🔴 已修：
- `debhelper` 进 apt 清单（release.yml:22）——`dpkg-buildpackage` 不再 unmet；
- rpm 步骤 `sed -i "s/^Version:.*/Version: ${VERSION}/"` + 弃用无效的 `--define version`——Worker 本地模拟 `VERSION=9.9.9` 产出 `nosd-theme-9.9.9-1.noarch.rpm`，spec 已还原 `0.1.0`。

YAML 解析通过；PLAN §6.5「tag 触发 CI，产出 deb / rpm / tar.gz」口径现已与 release.yml 一致。

**终审结论：PASS** — release.yml 与打包脚本全链路一致，剩余未验证项仅「CI 真跑」（无 tag 未触发）与 deb 的 `dpkg-buildpackage` 原命令在 CI 上的首跑结果，属合理残余。
