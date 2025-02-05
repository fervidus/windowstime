# Class: windowstime
# ===========================
#
# A module to manage windows time configuration.
#
# Parameters
# ----------
# @param [Hash] servers
#   List of time servers
# @param [Array] timezones
#   List of timezones
# @param [Optional[String]] timezone
#    Timezone
#    Default value: undef
# @param [String] syncflag
#    Sync flag
#    Default value: 'local'
#
#
# * 'servers'
# A hash of time servers, including the configuration flags as follows:
#
# 0x01 SpecialInterval
# 0x02 UseAsFallbackOnly
# 0x04 SymmatricActive
# 0x08 Client
# The Params class contains some sane defaults:
#   $servers = { 'pool.ntp.org'     => '0x01',
#               'time.windows.com' => '0x01',
#               'time.nist.gov'    => '0x02',
#  }
#
# * 'syncflag'
# Allows specification of syncing from local ntp server or domain hierarchy. Possible values are:
# 'local'
# 'domain'
# The default is 'local'.
#
# Examples
# --------
#
# @example
#    class { 'windowstime':
#      servers => { 'pool.ntp.org'     => '0x01',
#                   'time.windows.com' => '0x01',
#                 }
#    }
#
# Authors
# -------
#
# Nicolas Corrarello <nicolas@puppet.com>
#
# Copyright
# ---------
#
# Copyright 2016 Your name here, unless otherwise noted.
#

class windowstime (
  Hash $servers = {},
  Array $timezones = [],
  Optional[String] $timezone = undef,
  String $syncflag = 'local',
) {
  $regvalue = maptoreg($servers)
  $normalized_timezone_fact = regsubst($facts['timezone'], 'Daylight', 'Standard')
  $synctype = $syncflag ? {
    'local' => 'NTP',
    'domain' => 'NT5DS',
    default  => 'NTP',
  }

  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters\Type':
    ensure => present,
    type   => string,
    data   => $synctype,
    notify => Service['w32time'],
  }

  registry_value { 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time\Parameters\NtpServer':
    ensure => present,
    type   => string,
    data   => $regvalue,
    notify => Service['w32time'],
  }

  exec { 'c:/Windows/System32/w32tm.exe /resync':
    refreshonly => true,
  }

  service { 'w32time':
    ensure => running,
    enable => true,
    notify => Exec['c:/Windows/System32/w32tm.exe /resync'],
  }

  if $timezone {
    validate_re($timezone, $timezones, 'The specified string is not a valid Timezone')
    if $timezone != $normalized_timezone_fact {
      $system32dir = $facts['os']['windows']['system32']
      exec { "${system32dir}\\tzutil.exe /s \"${timezone}\"":
        notify => Exec['c:/Windows/System32/w32tm.exe /resync'],
      }
    }
  }
}
