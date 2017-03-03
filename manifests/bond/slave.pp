# == Definition: network::bond::slave
#
# Creates a bonded slave interface.
#
# === Parameters:
#
#   $macaddress   - required
#   $master       - required
#   $ethtool_opts - optional
#
# === Actions:
#
# Deploys the file /etc/sysconfig/network-scripts/ifcfg-$name.
#
# === Requires:
#
#   Service['network']
#
# === Sample Usage:
#
#   network::bond::slave { 'eth1':
#     macaddress => $::macaddress_eth1,
#     master     => 'bond0',
#   }
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2011 Mike Arnold, unless otherwise noted.
#
define network::bond::slave (
  $macaddress,
  $master,
  $device = $title,
  $ethtool_opts = undef,
  $zone = undef,
  $defroute = undef,
  $metric = undef,
  $ensure = 'up',
) {
  # Validate our data
  if ! is_mac_address($macaddress) {
    fail("${macaddress} is not a MAC address.")
  }

  include '::network'

  $ifname = $title

  file { "ifcfg-${ifname}":
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    path    => "/etc/sysconfig/network-scripts/ifcfg-${ifname}",
    content => template('network/ifcfg-bond.erb'),
    before  => File["ifcfg-${master}"],
    notify  => Exec["nmcli_config_${ifname}"],
  }
  exec { "nmcli_clean_${ifname}":
    path    => '/usr/bin:/bin:/usr/sbin:/sbin',
    command => "nmcli connection delete $(nmcli -f UUID,DEVICE connection show|grep \'\\-\\-\'|awk \'{print \$1}\')",
    onlyif  => "nmcli -f UUID,DEVICE connection show|grep \'\\-\\-\'",
    require => Exec["nmcli_manage_${ifname}"]
  }

  exec { "nmcli_config_${ifname}":
    path        => '/usr/bin:/bin:/usr/sbin:/sbin',
    command     => "nmcli connection load /etc/sysconfig/network-scripts/ifcfg-${ifname}",
    refreshonly => true,
    notify      => Exec["nmcli_manage_${ifname}"],
  }

  exec { "nmcli_manage_${ifname}":
    path        => '/usr/bin:/bin:/usr/sbin:/sbin',
    command     => "nmcli connection ${ensure} ${ifname}",
    refreshonly => true,
    notify      => Exec["nmcli_clean_${ifname}"],
    require     => Exec["nmcli_config_${ifname}"]
  }
} # define network::bond::slave
