#!/bin/bash

yum install sudo rng-tools postgresql-server httpd httpd-devel mod_ssl gcc make expat expat-devel mod_perl mod_perl-devel perl-Digest-SHA perl-Digest-SHA libxml2 libxml2-devel perl-XML-LibXML uuid-perl perl-DBD-Pg bind perl-XML-RSS perl-JSON rsync perl-Unicode-String perl-Config-Simple perl-Module-Pluggable perl-MIME-Lite perl-CPAN perl-Class-Accessor perl-YAML perl-XML-Parser uuid uuid-devel uuid-perl perl-Net-DNS perl-DateTime-Format-DateParse perl-IO-Socket-INET6 openssl-devel perl-Module-Install wget perl-Net-SSLeay perl-Class-Trigger perl-Date-Manip libuuid-devel

wget http://dl.fedoraproject.org/pub/epel/6/x86_64/libapreq2-2.13-1.el6.x86_64.rpm
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/libapreq2-devel-2.13-1.el6.x86_64.rpm
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/perl-libapreq2-2.13-1.el6.x86_64.rpm
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/zeromq-2.1.9-1.el6.x86_64.rpm
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/zeromq-devel-2.1.9-1.el6.x86_64.rpm
sudo rpm -i libapreq2-2.13-1.el6.x86_64.rpm libapreq2-devel-2.13-1.el6.x86_64.rpm perl-libapreq2-2.13-1.el6.x86_64.rpm zeromq-2.1.9-1.el6.x86_64.rpm zeromq-devel-2.1.9-1.el6.x86_64.rpm

sudo PERL_MM_USE_DEFAULT=1 perl -MCPAN -e 'install Net::Abuse::Utils,Linux::Cpuinfo,Google::ProtocolBuffers,Iodef::Pb::Simple,Compress::Snappy,Net::Abuse::Utils::Spamhaus,Net::DNS::Match,Snort::Rule,Parse::Range,Log::Dispatch,ZeroMQ,Sys::MemInfo, JSON::XS,File::Type,LWP::UserAgent,Class::Trigger,LWP::Protocol::https,Class::DBI,Net::Patricia,Text::Table,Regexp::Common::net, Regexp::Common::net::CIDR'

wget http://search.cpan.org/CPAN/authors/id/M/MI/MIKEM/Net-SSLeay-1.49.tar.gz
tar -zxvf Net-SSLeay-1.49.tar.gz
cd Net-SSLeay-1.49
PERL_MM_USE_DEFAULT=1 perl Makefile.PL
sudo make install
cd ../

wget http://search.cpan.org/CPAN/authors/id/S/SH/SHLOMIF/IO-Socket-INET6-2.69.tar.gz
tar -zxvf IO-Socket-INET6-2.69.tar.gz
cd IO-Socket-INET6-2.69
PERL_MM_USE_DEFAULT=1 perl Makefile.PL && sudo make install
cd ../

echo "DNS1=127.0.01" >> /etc/sysconfig/network-scripts/ifcfg-eth0
sudo service network restart

sudo service postgresql initdb

sudo mkdir -p /etc/postgresql/8.4/main
sudo chown -R postgres:postgres /etc/postgresql
sudo chmod 760 -R /etc/postgresql
sudo ln -sf /var/lib/pgsql/data/postgresql.conf /etc/postgresql/8.4/main/postgresql.conf
sudo ln -sf /var/lib/pgsql/data/pg_hba.conf /etc/postgresql/8.4/main/pg_hba.conf
sudo service postgresql start

sudo adduser cif
sudo chmod 770 /home/cif

# apache stuff, add the rest

sudo usermod -a -G cif apache

# rng options here

# get things into startup

sudo chkconfig --levels 345 postgresql on
sudo chkconfig --levels 345 named on
sudo chkconfig --levels 345 rngd on
sudo chkconfig --levels 345 httpd on