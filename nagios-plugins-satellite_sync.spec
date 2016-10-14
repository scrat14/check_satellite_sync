Name:		nagios-plugins-satellite_sync
Version:	0.1
Release:	1%{?dist}
Summary:	Red Hat Satellite 6 repositoriy sync monitoring plugin for Nagios/Icinga

Group:		Applications/System
License:	GPLv2+
URL:		https://github.com/scrat14/check_satellite_sync
Source0:	check_satellite_sync-%{version}.tar.gz
BuildRoot:	%{_tmppath}/check_satellite_sync-%{version}-%{release}-root

BuildRequires:	perl-Crypt-SSLeay
BuildRequires:	perl-libwww-perl
BuildRequires:	perl-JSON-PP

Requires:	perl-Crypt-SSLeay
Requires:	perl-libwww-perl
Requires:	perl-JSON-PP

%description
This plugin for Icinga/Nagios is used to monitor if last content 
sync status of repositories was successful.

%prep
%setup -q -n check_satellite_sync-%{version}

%build
%configure --prefix=%{_libdir}/nagios/plugins \
	   --with-nagios-user=nagios \
	   --with-nagios-group=nagios

make all


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT INSTALL_OPTS=""

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(0755,nagios,nagios)
%{_libdir}/nagios/plugins/check_satellite_sync
%doc README INSTALL NEWS ChangeLog COPYING



%changelog
* Fri Oct 14 2016 Rene Koch <rkoch@rk-it.at> 0.1-1
- Initial build.

