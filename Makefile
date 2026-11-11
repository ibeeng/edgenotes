PREFIX ?= /usr/local

.PHONY: install uninstall check

install:
	install -Dm755 edgenotes $(DESTDIR)$(PREFIX)/bin/edgenotes
	install -Dm644 data/edgenotes.desktop $(DESTDIR)$(PREFIX)/share/applications/edgenotes.desktop
	install -Dm644 data/edgenotes.svg $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/edgenotes.svg
	install -Dm644 data/qris.jpg $(DESTDIR)$(PREFIX)/share/edgenotes/qris.jpg
	-gtk-update-icon-cache -q $(DESTDIR)$(PREFIX)/share/icons/hicolor 2>/dev/null

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/edgenotes
	rm -f $(DESTDIR)$(PREFIX)/share/applications/edgenotes.desktop
	rm -f $(DESTDIR)$(PREFIX)/share/icons/hicolor/scalable/apps/edgenotes.svg
	rm -rf $(DESTDIR)$(PREFIX)/share/edgenotes

check:
	python3 -m py_compile edgenotes && echo "OK"
