PREFIX = /usr

all: 

install: install-gtk install-kvantum

# 产物 1/1'：GTK2/3/4 主题（deepin 浅色 + deepin-dark 深色）
install-gtk: 
	mkdir -p $(DESTDIR)$(PREFIX)/share/themes
	cp -r deepin $(DESTDIR)$(PREFIX)/share/themes/
	cp -r deepin-dark $(DESTDIR)$(PREFIX)/share/themes/

# 产物 2：Kvantum 主题（nosd，静态 SVG + kvconfig）
install-kvantum: 
	mkdir -p $(DESTDIR)$(PREFIX)/share/Kvantum
	cp -r kvantum/nosd $(DESTDIR)$(PREFIX)/share/Kvantum/

# 用户目录安装。Cinnamon / GNOME Shell 的取色注入点（各 shell 目录下的
# nosd-accent.css）只有装在用户主题目录里才写得进去：nosDshell 按
# ~/.local/share/themes/<theme>/{cinnamon,gnome-shell}/ 生成覆盖文件。
# 系统级安装（PREFIX=/usr）不生成覆盖文件，St 侧退化为静态 accent。
install-user:
	$(MAKE) install PREFIX=$(HOME)/.local

check: 
	python3 scripts/check-tokens.py .

.PHONY: all install install-gtk install-kvantum install-user check
