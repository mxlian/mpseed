Exec { path => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' }


$user = 'admin' # User to create
$password = 'abcdef1' # The user's password
$password_hash = '$6$AmBNh8J7nMlCZcl$kiCaNL0ex.7Oab13v1jJy5QFzdd95KjSIhNgkubjLGQhkajUC0Uw2u6pXJ.t5c9oirHctq2MmZDlEIy3P3cgt0'

if $projectid == undef {
    fail("Sorry man, you suck: 'projectid fact not defined'")
}
$project = "${projectid}" 

if $internet == 'false' {
    notice("Trying to run puppet without internet connection")
    $pip_packages_path = "/tmp/pip_packages"
    $package_version = 'present'
    $apt_update = false
    $extra_pip_args = "--no-index --find-links ${pip_packages_path}"
}
else {
    notice("Running puppet with internet connection")
    $package_version = 'latest'
    $apt_update = true
    $extra_pip_args = ''
}

# Global variables
$project_path = "/var/www/${project}" # Base dir
$repo_path = "${project_path}/repo" # Git repo (or repository 'snapshot')
$mpseed_path = "${repo_path}/mpseed" # MPSEED sources
$inc_file_path = "${mpseed_path}/files" # Include files for this puppet manifest

# Database
$db_name = "${project}" # Mysql database name to create
$db_user = "${project}" # Mysql username to create
$db_password = "${project}" # Mysql password for $db_user

# Environment
$domain_name = "${project}.mainstorconcept.de" # Used in nginx, uwsgi and virtualenv directory
$tz = 'Europe/Berlin' # Timezone
$alias_run_puppet="alias pp='sudo FACTER_PROJECTID=${project} puppet apply --debug ${mpseed_path}/manifests/main.pp'"
$alias_run_puppet_extras="alias ppe='sudo FACTER_PROJECTID=${project} puppet apply --debug ${repo_path}/puppet_extras.pp'"
$fabric_local_deploy="fab deploy:host=${user}@localhost --password=${password} --fabfile=${repo_path}/fabfile.py"

include users
include paquetes
include database
include app_sources
include virtualenv
include app_deploy
include nginx
include uwsgi
include timezone

Class['apt'] -> Class['python']      
Class['apt'] -> Class['paquetes']      
Class['apt'] -> Class['database']      
Class['apt'] -> Class['app_sources']   
Class['apt'] -> Class['virtualenv']    
Class['apt'] -> Class['app_deploy']    
Class['apt'] -> Class['nginx']         
Class['apt'] -> Class['uwsgi']         
Class['apt'] -> Class['timezone']      

class { 'apt':
  always_apt_update    => $apt_update,
}

class { 'python':
    dev        => true, # install python-dev
    pip        => true,
    version    => 'system',
    virtualenv => true,
}

class users {
    group { 'www-data':
        ensure => present,
    }
    user { 'www-data':
        ensure => present,
        groups => ['www-data'],
        membership => minimum,
        shell => "/bin/bash",
        require => Group['www-data']
    }
    user { $user:
      ensure     => "present",
      managehome => true,
      shell => "/bin/bash",
      password => $password_hash,
      groups => ['sudo',] # 'vagrant'], On bare matal there is no vagrant
    }
    # SSH Keys
    file { "/home/$user/.ssh/":
        ensure  => present,
        owner   => "$user",
        group   => "$user",
        mode    => '0600',
        source  =>"${inc_file_path}/ssh/",
        recurse => true;
    }
    file { "/home/$user/.bash_aliases":
        ensure => "file",
        owner  => "$user",
        group  => "$user",
        content  => "alias wd='cd ${repo_path}; source ${project_path}/env/bin/activate'
                   \nalias run='${repo_path}/webapp/manage.py runserver 0.0.0.0:8888'
                   \nalias ff='${fabric_local_deploy}'
                   \n${alias_run_puppet}
                   \n${alias_run_puppet_extras}",
        mode   => 755,
    }

    # NO VAGRANT on barematal machines
    ## Be nice with vagrant user too
    #file { "/home/vagrant/.bash_aliases":
    #    ensure => "file",
    #    owner  => "vagrant",
    #    group  => "vagrant",
    #    content  => "${alias_run_puppet}
    #               \n${alias_run_puppet_extras}",
    #    mode   => 755,
    #}
}


class virtualenv {
    python::virtualenv { "${project_path}/env":
        ensure       => present,
        version      => 'system',
        requirements => "${repo_path}/webapp/requirements.txt",
        distribute   => false,
        owner        => "www-data",
        group        => "$user",
        timeout      => 100,
        require => [Class['app_sources'], Class['database']],
        before => Class['app_deploy'],
        extra_pip_args  => $extra_pip_args,
    }
}

class paquetes {

    $essentials = [ 'git', 'ifenslave', 'vim', 'ipython', 'screen', 'httpie', 'zip', 'unzip']
    package { $essentials: ensure => $package_version }

    package { ['fabric==1.8.1', 'pycrypto', 'ecdsa']:
        ensure => present,
        provider => pip,
        require => Package['python-pip']
    }
}

class app_sources {
    $dirs = [ "/var/www", 
              "${project_path}",
#              "${project_path}/env",
] 
    file { $dirs:
        ensure => "directory",
        owner  => "$user",
        group  => "$user",
        mode   => 755,
    }
    file { ["${project_path}/static",
            "${project_path}/media",]: 
        ensure => "directory",
        mode => 777,
    }
    file { "/etc/puppet/hiera.yaml":
         ensure => "present",
    }
    # Default to play nice with vagrant and with first install
    file { "${repo_path}/":
        ensure => link,
        target => '/repo/',
    } 
    file { "/var/log/${project}":
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'admin',
        mode   => 664
    } 
    #vcsrepo { "${repo_path}":
    #    #ensure => present,
    #    ensure => $package_version,
    #    provider => git,
    #    source => "git://redmine.mainstorconcept.de/vtfx-II.git",
    #    revision => 'master',
    #    user => "$user",
    #    require => Package['git']
    #}
}

class app_deploy {
    exec {$fabric_local_deploy:
        provider=> shell,
        logoutput => true,
        #path    => ["/usr/bin", "/usr/sbin"]
    }
    file { "/etc/sudoers.d/20-update":
        content => "
            Defaults!/usr/bin/puppet env_keep+=FACTER_PROJECTID
            Defaults!/usr/bin/puppet env_keep+=FACTER_INTERNET
            www-data ALL=(ALL) NOPASSWD:/usr/bin/puppet apply *
        ",
    }
}

class database {
    if $unmodify_db == undef or $unmodify_db != 'True' {
        $postgres = [ 'postgresql', 'libpq-dev', ]
        package { $postgres: ensure => $package_version }

        class { 'postgresql::server':
            ip_mask_deny_postgres_user => '0.0.0.0/32',
            ip_mask_allow_all_users    => '0.0.0.0/0',
            listen_addresses           => '*',
            #ipv4acls                   => ['hostssl all johndoe 192.168.0.0/24 cert'],
            #manage_firewall            => true,
            postgres_password          => 'postgres',
        }
        postgresql::server::db { $db_name:
            user     => $db_user,
            password => postgresql_password($db_user, $db_password),
        }
        cron { 'postgres vacuuming':
            command => "/usr/bin/vacuumdb --all --analyze --verbose > /tmp/postgres_vacuum_analyze.log 2>&1",
            user    => 'postgres',
            minute  => '1',
            hour  => '5',
        }
    }
}

class uwsgi {
    package { ['uwsgi', 'uwsgi-plugin-python']:
        ensure => present,
        require => Class['paquetes'],
    }
    file { "/etc/uwsgi/apps-available/${project}.ini":
        ensure => present,
        owner => 'root',
        group => 'root',
        mode => '0644',
        content => template("${inc_file_path}/uwsgi/main.erb"),
        #source =>"${inc_file_path}/uwsgi/main.ini",
        require => Package['uwsgi'],
    }
    file { "/etc/uwsgi/apps-enabled/${project}.ini":
        ensure => link,
        target => "/etc/uwsgi/apps-available/${project}.ini",
        require => Package['uwsgi'],
    } 
    service { 'uwsgi':
        ensure => running,
        provider => upstart,
        enable => true,
        hasrestart => false,
        hasstatus => false,
        require => [ File["/etc/uwsgi/apps-enabled/${project}.ini"], Class['virtualenv'] ],
        subscribe => File["/etc/uwsgi/apps-available/${project}.ini"],
    }
}

class nginx {
    package { 'nginx':
        ensure => present,
        require => Class['paquetes'],
    }
    file { "/etc/nginx/sites-available/${project}":
        ensure => file,
        owner => 'root',
        group => 'root',
        mode => '640',
        #source =>"${inc_file_path}/nginx/${project}",
        content => template("${inc_file_path}/nginx/main.erb"),
        require => Package['nginx'],
    }
    # Disable default config
    file { "/etc/nginx/sites-enabled/default":
        ensure => absent,
        require => Package['nginx'],
    } 
    file { "/etc/nginx/sites-enabled/${project}":
        ensure => link,
        target => "/etc/nginx/sites-available/${project}",
        require => Package['nginx'],
    } 
    service { 'nginx':
        ensure => running,
        enable => true,
        hasstatus => true,
        hasrestart => true,
        subscribe => File["/etc/nginx/sites-available/${project}"],
    }
}

class timezone {
  package { "tzdata":
    ensure => $package_version,
  }
  file { "/etc/localtime":
    require => Package["tzdata"],
    source => "file:///usr/share/zoneinfo/${tz}",
  }
}
