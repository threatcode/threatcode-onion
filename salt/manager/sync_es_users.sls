include:
  - elasticsearch.auth
  - kratos

tc-user.lock:
  file.missing:
    - name: /var/tmp/tc-user.lock

# Must run before elasticsearch docker container is started!
sync_es_users:
  cmd.run:
    - name: tc-user sync
    - env:
      - SKIP_STATE_APPLY: 'true'
    - creates:
      - /opt/tc/saltstack/local/salt/elasticsearch/files/users
      - /opt/tc/saltstack/local/salt/elasticsearch/files/users_roles
      - /opt/tc/conf/soc/soc_users_roles
    - show_changes: False
    - require:
      - docker_container: tc-kratos
      - http: wait_for_kratos
      - file: tc-user.lock # require tc-user.lock file to be missing

# we dont want this added too early in setup, so we add the onlyif to verify 'startup_states: highstate'
# is in the minion config. That line is added before the final highstate during setup
sosyncusers:
  cron.present:
    - user: root
    - name: 'PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin /usr/sbin/tc-user sync &>> /opt/tc/log/soc/sync.log'
    - onlyif: "grep 'startup_states: highstate' /etc/salt/minion"
