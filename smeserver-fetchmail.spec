# $Id: smeserver-fetchmail.spec,v 1.2 2013/07/14 20:52:55 unnilennium Exp $
# Authority: unnilennium
# Name: Jean-Philippe Pialasse 

Summary: sme module to generate fetchmail poll
%define name smeserver-fetchmail
Name: %{name}
%define version 1.4
%define release 2
%define smepanel FetchMails
Version: %{version}
Release: %{release}%{?dist}
License: GPL
Group: Networking/Daemons
Source: %{name}-%{version}.tgz
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-buildroot
BuildArchitectures: noarch
Requires: smeserver-release >= 8.0
Requires: e-smith-email >= 4.16.0-18
Requires: e-smith-formmagick >= 1.4.0-12
BuildRequires: e-smith-devtools >= 1.13.1-03
Obsoletes: sme-fetchmail
Obsoletes: smeserver-fetchmail-utf8
AutoReqProv: no

%changelog
* Sun Jul 14 2013 JP Pialasse <tests@pialasse.com> 1.4-2.sme
- apply locale 2013-07-14 patch

* Sun Jun 3 2012 JP PIALASSE tests@pialasse.com  1.4-1.sme
- Initial version

%description
sme server enhancement to make fetchmail more useable

%prep
%setup

%build
perl createlinks
echo "%{version}-%{release}" >root/etc/e-smith/db/configuration/defaults/%{smepanel}/version

%install
rm -rf $RPM_BUILD_ROOT
(cd root   ; find . -depth -print | cpio -dump $RPM_BUILD_ROOT)
rm -f %{name}-%{version}-filelist
/sbin/e-smith/genfilelist $RPM_BUILD_ROOT > %{name}-%{version}-filelist
echo "%doc COPYING"          >> %{name}-%{version}-filelist

%clean 
rm -rf $RPM_BUILD_ROOT

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
