Name:           nosd-gtk-theme
Version:        0.2.0
Release:        1
Summary:        nosDshell GTK themes
License:        GPLv3
URL:            https://github.com/nosDshell/nosd
Source0:        %{url}/releases/download/%{name}-v%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch
Provides:       nosd-app-themes = %{version}-%{release}
Obsoletes:      nosd-app-themes < %{version}-%{release}
Provides:       deepin-gtk-theme = %{version}-%{release}
Obsoletes:      deepin-gtk-theme < %{version}-%{release}

%description
Deepin-style GTK+ 2/3/4 themes (deepin light and deepin-dark) for the
nosDshell desktop environment.  The Kvantum Qt theme is packaged
separately as nosd-kvantum-theme.

%prep
%setup -q

%build

%install
%make_install PREFIX=%{_prefix}

%files
%doc README.md README.zh_CN.md CHANGELOG.md
%license LICENSE
%{_datadir}/themes/deepin/
%{_datadir}/themes/deepin-dark/

%changelog
* Sat Nov 15 2026 nosDshell Theme Maintainers <noreply@nosdshell.org> - 0.2.0-1
- split from nosd-app-themes into the nosd-gtk-theme monorepo component;
  Kvantum theme is now the separate nosd-kvantum-theme package

* Sat Nov 14 2026 nosDshell Theme Maintainers <noreply@nosdshell.org> - 0.2.0-1
- palette-driven GTK indicators; fix override bypass, headerbar and popover contract drift

* Thu Nov 13 2025 nosDshell Theme Maintainers <noreply@nosdshell.org> - 0.1.0-1
- rebrand to nosd-app-themes; add Kvantum nosd theme
