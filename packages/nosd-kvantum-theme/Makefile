PREFIX = /usr

all: 

install: 
	mkdir -p $(DESTDIR)$(PREFIX)/share/Kvantum
	cp -r nosd $(DESTDIR)$(PREFIX)/share/Kvantum/

check: 
	python3 ../../tools/check-tokens.py ../..

.PHONY: all install check
