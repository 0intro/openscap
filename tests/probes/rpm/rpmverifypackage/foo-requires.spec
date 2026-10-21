Summary: Test package foo-requires
Name: foo-requires
Version: 1.0
Release: 1
Group: Testing
License: GPLv2+
BuildArch: noarch
Requires: foo

%description
Simple rpm test package (%{name}) that requires the package foo.

%prep
mkdir -p %{buildroot}%{_sysconfdir}
echo "%{name}" > %{buildroot}%{_sysconfdir}/%{name}

%files
%{_sysconfdir}/%{name}
