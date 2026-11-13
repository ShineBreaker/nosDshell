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

check: 
	python3 scripts/check-tokens.py .

.PHONY: all install install-gtk install-kvantum check
