%global debug_package %{nil}
%global __os_install_post %{nil}
AutoReqProv: no

Name: backlog-manager
Version: %{app_version}
Release: 1%{?dist}
Summary: Game backlog manager
License: Proprietary
URL: https://github.com/theoleuthardt/backlog-manager
BuildArch: x86_64
Requires: gtk3, libsecret, webkit2gtk4.1, libsoup3

%description
Backlog Manager desktop client: track and organise a game backlog with data from HowLongToBeat, IGDB and Steam.

%install
install -d %{buildroot}%{_datadir}/%{name}
cp -r %{app_bundle}/. %{buildroot}%{_datadir}/%{name}
install -d %{buildroot}%{_bindir}
ln -s %{_datadir}/%{name}/backlog_manager %{buildroot}%{_bindir}/%{name}
install -Dm644 %{app_desktop} %{buildroot}%{_datadir}/applications/%{name}.desktop
install -Dm644 %{app_icon} %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/%{name}.png

%files
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/512x512/apps/%{name}.png
