{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set MANAGER = salt['grains.get']('master') %}
{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}

include:
  - ssl

# add Telegraf to monitor all the things
tgraflogdir:
  file.directory:
    - name: /opt/tc/log/telegraf
    - makedirs: True
    - user: 939
    - group: 939
    - recurse:
      - user
      - group
      
tgrafetcdir:
  file.directory:
    - name: /opt/tc/conf/telegraf/etc
    - makedirs: True

tgrafetsdir:
  file.directory:
    - name: /opt/tc/conf/telegraf/scripts
    - makedirs: True

tgrafsyncscripts:
  file.recurse:
    - name: /opt/tc/conf/telegraf/scripts
    - user: root
    - group: 939
    - file_mode: 770
    - template: jinja
    - source: salt://telegraf/scripts
{% if salt['pillar.get']('global:mdengine', 'ZEEK') == 'SURICATA' %}
    - exclude_pat: zeekcaptureloss.sh
{% endif %}

tgrafconf:
  file.managed:
    - name: /opt/tc/conf/telegraf/etc/telegraf.conf
    - user: 939
    - group: 939
    - mode: 660
    - template: jinja
    - source: salt://telegraf/etc/telegraf.conf
    - show_changes: False

# this file will be read by telegraf to send node details (management interface, monitor interface, etc)
# into influx so that Grafana can build dashboards using queries
node_config:
  file.managed:
    - name: /opt/tc/conf/telegraf/node_config.json
    - source: salt://telegraf/node_config.json.jinja
    - template: jinja

tc-telegraf:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-telegraf:{{ VERSION }}
    - user: 939
    - group_add: 939,920
    - environment:
      - HOST_PROC=/host/proc
      - HOST_ETC=/host/etc
      - HOST_SYS=/host/sys
      - HOST_MOUNT_PREFIX=/host
      - GODEBUG=x509ignoreCN=0
    - network_mode: host
    - init: True
    - binds:
      - /opt/tc/log/telegraf:/var/log/telegraf:rw
      - /opt/tc/conf/telegraf/etc/telegraf.conf:/etc/telegraf/telegraf.conf:ro
      - /opt/tc/conf/telegraf/node_config.json:/etc/telegraf/node_config.json:ro
      - /var/run/utmp:/var/run/utmp:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /:/host/root:ro
      - /sys:/host/sys:ro
      - /proc:/host/proc:ro
      - /nsm:/host/nsm:ro
      - /etc:/host/etc:ro
      {% if grains['role'] == 'tc-manager' or grains['role'] == 'tc-eval' or grains['role'] == 'tc-managersearch' %}
      - /etc/pki/ca.crt:/etc/telegraf/ca.crt:ro
      {% else %}
      - /etc/ssl/certs/intca.crt:/etc/telegraf/ca.crt:ro
      {% endif %}
      - /etc/pki/influxdb.crt:/etc/telegraf/telegraf.crt:ro
      - /etc/pki/influxdb.key:/etc/telegraf/telegraf.key:ro
      - /opt/tc/conf/telegraf/scripts:/scripts:ro
      - /opt/tc/log/stenographer:/var/log/stenographer:ro
      - /opt/tc/log/suricata:/var/log/suricata:ro
      - /opt/tc/log/raid:/var/log/raid:ro
      - /opt/tc/log/tcstatus:/var/log/tcstatus:ro
    - watch:
      - file: tgrafconf
      - file: tgrafsyncscripts
      - file: node_config
    - require: 
      - file: tgrafconf
      - file: node_config
      {% if grains['role'] == 'tc-manager' or grains['role'] == 'tc-eval' or grains['role'] == 'tc-managersearch' %}
      - x509: pki_public_ca_crt
      {% else %}
      - x509: trusttheca
      {% endif %}
      - x509: influxdb_crt
      - x509: influxdb_key
append_tc-telegraf_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-telegraf

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
