Name:           nosd-theme
Version:        0.1.0
Release:        1
Summary:        nosDshell GTK and Kvantum themes
License:        GPLv3
URL:            https://github.com/nosDshell/nosd-theme
Source0:        %{url}/archive/%{version}/%{name}-%{version}.tar.gz
BuildArch:      noarch
Provides:       deepin-gtk-theme = %{version}-%{release}
Obsoletes:      deepin-gtk-theme < %{version}-%{release}

%description
Deepin-style GTK+ 2/3/4 themes (deepin light and deepin-dark) plus the
nosd Kvantum Qt widget theme, for the nosDshell desktop environment.

%prep
%setup -q

%build

%install
%make_install PREFIX=%{_prefix}

%files
%doc README.md README.zh_CN.md
%license LICENSE
%{_datadir}/themes/deepin/
%{_datadir}/themes/deepin-dark/
%{_datadir}/Kvantum/nosd/

%changelog
* Thu Nov 13 2025 nosDshell Theme Maintainers <noreply@nosdshell.org> - 0.1.0-1
- rebrand to nosd-theme; add Kvantum nosd theme
