
#$FACTER_git_server= 
#$FACTER_git_user=
#$FACTER_git_password= 
#FACTER_gem_source_url=

$control_repo_staging_dir = '/tmp/control-repo-staging'

$initrepo_user           = 'root'
$initrepo_sshkey_file    = '/root/.ssh/initrepo_id_rsa' 
$r10k_sshkey_file        = '/root/.ssh/r10k_id_rsa'

$get_api_token_cmd       = "curl http://${git_server}/api/v3/session --data \"login=${git_user}&password=${git_password}\" | /usr/bin/jq -r \'.private_token\'"
$gitlab_api_token_file   = '/tmp/gitlab_api_token'
$project_name            = "control-repo"

package { 'jq':
  ensure => installed,
}

exec {'create_api_token_file':
  require => Package['jq'],
  path    => '/usr/bin',
  command => "$get_api_token_cmd > ${gitlab_api_token_file}",
  creates => $gitlab_api_token_file,
}

ssh_keygen { 'initrepo':
  user     => 'root',
  type     => 'rsa',
  filename => $initrepo_sshkey_file,
  bits     => '4096',
}

ssh_keygen { 'r10k_deploy':
  user     => 'root',
  type     => 'rsa',
  filename => $r10k_sshkey_file,
  bits     => '4096',
}

# Defined resource for setting up gitlab via api...
define set_data (
    String $data_title = $title,
    String $uri_scheme,
    String $uri_host,
    String $uri_path,
    String $uri_query,
    String $header,
    String $data,
    String $curl_bin,
){
  $set_cmd    = "curl -s -H ${header} ${uri_scheme}://${uri_host}${uri_path}${uri_query} -d \"${data}\""
  $check_data = delete(split($data,',')[0],['{','}',' ','\\']) # Use the first value in the hash, remove braces for grep...
  $unless_cmd = "[ \$(curl -s -H ${header} ${uri_scheme}://${uri_host}${uri_path}${uri_query} -X GET | /usr/bin/grep -o \'${check_data}\') ]"
  exec { "set_data_${data_title}":
    path        => $curl_bin,
    require     => Package['jq'],
    command     => $set_cmd,
    unless      => $unless_cmd,
  }
}

Set_data {
  header     => "\"Content-Type:application/json\"",
  uri_scheme => 'http',
  uri_host   => "${git_server}",
  uri_query  => "?private_token=\$(${get_api_token_cmd})",
  curl_bin   => '/usr/bin:/usr/sbin',
}

set_data {"projects_${project_name}":
  uri_path  => "/api/v3/projects",
  data      => "{\\\"name\\\":\\\"${project_name}\\\"}",
}

set_data {"user_keys_${initrepo_user}":
  require   => Ssh_keygen['initrepo'],
  uri_path  => "/api/v3/user/keys",
  data      => "{\\\"title\\\":\\\"${initrepo_user}\\\",\\\"key\\\":\\\"\$(cat ${initrepo_sshkey_file}.pub)\\\"}",
}

git_deploy_key { 'gitlab_deploy_key_for_control_repo':
  require      => [ Ssh_keygen['r10k_deploy'], Set_data["projects_${project_name}"], Exec['create_api_token_file'] ],
  ensure       => present,
  name         => $::fqdn,
  path         => "${r10k_sshkey_file}.pub",
  token_file   => $gitlab_api_token_file,
  project_name => 'root/control-repo',
  server_url   => "http://${git_server}",
  provider     => 'gitlab',
}

  #####
  # Push the template control-repo to repo on gitlab box (already previously staged to: $control_repo_staging_dir)...
  # We are assuming a template control-repo has already been staged here to cwd)
  $control_repo_origin = "git@${git_server}:${initrepo_user}/control-repo.git"
  $init_control_repo_sh_file = '/tmp/init_control_repo.sh'
  $init_control_repo_sh_content = [
    "ssh-keyscan ${git_server} >> /${initrepo_user}/.ssh/known_hosts",
    "&& cd ${control_repo_staging_dir}",
    "&& git remote remove origin",
    "; eval \"\$(ssh-agent -s)\" && ssh-add ${initrepo_sshkey_file}",
    "&& git remote add origin ${control_repo_origin}",
    "&& git push -u origin --all && git push -u origin --tags",
    "&& rm -rf ${control_repo_staging_dir}/.git"
  ].join(' ')
  file { $init_control_repo_sh_file:
    ensure  => file,
    content => $init_control_repo_sh_content,
    mode    => '0755',
    owner    => 'root',
    group   => 'root',
  }
  exec { "/bin/bash -c ${init_control_repo_sh_file}":
    require     => [
      Exec["add_host_${git_server}_to_known_hosts"],
      Set_data["user_keys_${initrepo_user}"],
    ],
    refreshonly => true,
    subscribe   => File[$init_control_repo_sh_file],
    cwd         => $control_repo_staging_dir, path    => '/bin/bash:/usr/bin',
    onlyif      => "test -d ${control_repo_staging_dir}/.git",
  }
  #####

  # Fix for puppet gem source defaulting to rubygems.org
  exec { "gem sources --remove https://rubygems.org":
    path    => '/opt/puppetlabs/puppet/bin',
  } 
  exec { "gem sources --add ${gem_source_url}":
    path    => '/opt/puppetlabs/puppet/bin',
  } 

  class { '::ruby': }
  class { '::ruby::gemrc': 
    sources => [$gem_source_url],
  }
  class { '::ruby::dev': require => Class['::ruby::gemrc'], }

  class {'r10k': 
    remote                 => $control_repo_origin,
    manage_ruby_dependency => 'ignore',
    require                => [
      Class['::ruby'],
      Exec["gem sources --add ${gem_source_url}"],
    ]
  }
