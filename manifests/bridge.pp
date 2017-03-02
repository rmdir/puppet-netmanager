# == Definition: network::bridge
#
# Creates a bridge interface with no IP information.
#
# === Parameters:
#
#   $ensure        - required - up|down
#   $userctl       - optional - defaults to false
#   $stp           - optional - defaults to false
#   $delay         - optional - defaults to 30
#   $bridging_opts - optional
#
# === Actions:
#
# Deploys the file /etc/sysconfig/network-scripts/ifcfg-$name.
#
# === Sample Usage:
#
#   network::bridge { 'br3':
#     ensure        => 'up',
#     stp           => true,
#     delay         => '0',
#     bridging_opts => 'hello_time=200',
#   }
#
# === Authors:
#
# Mike Arnold <mike@razorsedge.org>
#
# === Copyright:
#
# Copyright (C) 2013 Mike Arnold, unless otherwise noted.
#
define network::bridge (
  $ensure,
  $device = $title,
  $userctl = false,
  $stp = false,
  $delay = '30',
  $bridging_opts = undef,
  $ipv6init = false
) {
  # Validate our regular expressions
  $states = [ '^up$', '^down$' ]
  validate_re($ensure, $states, '$ensure must be either "up" or "down".')
  # Validate booleans
  validate_bool($userctl)
  validate_bool($stp)
  validate_bool($ipv6init)

  ensure_packages(['bridge-utils'])

  include '::network'

  $ifname = $title
  $bootproto = 'none'
  $ipaddress = undef
  $netmask = undef
  $gateway = undef
  $ipv6address = undef
  $ipv6gateway = undef

  $onboot = $ensure ? {
    'up'    => 'yes',
    'down'  => 'no',
    default => undef,
  }

  file { "ifcfg-${ifname}":
    ensure  => 'present',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    path    => "/etc/sysconfig/network-scripts/ifcfg-${ifname}",
    content => template('network/ifcfg-br.erb'),
    require => Package['bridge-utils'],
    notify  => Exec["nmcli_config_${ifname}"]
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
} # define network::bridge
