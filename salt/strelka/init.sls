# Copyright 2014-2023 Threat Code Solutions, LLC
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set MANAGER = salt['grains.get']('master') %}
{% set MANAGERIP = salt['pillar.get']('global:managerip', '') %}
{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set STRELKA_RULES = salt['pillar.get']('strelka:rules', '1') %}
{% set ENGINE = salt['pillar.get']('global:mdengine', '') %}
{% import_yaml 'strelka/defaults.yaml' as strelka_config with context %}
{% set IGNORELIST = salt['pillar.get']('strelka:ignore', strelka_config.strelka.ignore, merge=True, merge_nested_lists=True) %}

{% if ENGINE == "SURICATA" %}
  {% set filecheck_runas = 'suricata' %}
{% else %}
  {% set filecheck_runas = 'socore' %}
{% endif %}

{% if grains['os'] != 'CentOS' %}     
strelkapkgs:
  pkg.installed:
    - skip_suggestions: True
    - pkgs:
      - python3-watchdog
{% else %}
strelkapkgs:
  pkg.installed:
    - skip_suggestions: True
    - pkgs:
      - threatcode-python36-watchdog
{% endif %}
    
# Strelka config
strelkaconfdir:
  file.directory:
    - name: /opt/tc/conf/strelka
    - user: 939
    - group: 939
    - makedirs: True

strelkarulesdir:
  file.directory:
    - name: /opt/tc/conf/strelka/rules
    - user: 939
    - group: 939
    - makedirs: True

# Sync dynamic config to conf dir
strelkasync:
  file.recurse:
    - name: /opt/tc/conf/strelka/
    - source: salt://strelka/files
    - user: 939
    - group: 939
    - template: jinja

{% if STRELKA_RULES == 1 %}

strelkarules:
  file.recurse:
    - name: /opt/tc/conf/strelka/rules
    - source: salt://strelka/rules
    - user: 939
    - group: 939
    - clean: True
    - exclude_pat:
      {% for IGNOREDRULE in IGNORELIST %}
      - {{ IGNOREDRULE }}
      {% endfor %}

      {% for IGNOREDRULE in IGNORELIST %}
remove_rule_{{ IGNOREDRULE }}:
  file.absent:
    - name: /opt/tc/conf/strelka/rules/signature-base/{{ IGNOREDRULE }}
      {% endfor %}

{% if grains['role'] in ['tc-eval','tc-managersearch', 'tc-manager', 'tc-standalone', 'tc-import'] %}
strelkarepos:
  file.managed:
    - name: /opt/tc/saltstack/default/salt/strelka/rules/repos.txt
    - source: salt://strelka/rules/repos.txt.jinja
    - template: jinja

{% endif %}
{% endif %}

strelkadatadir:
  file.directory:
    - name: /nsm/strelka
    - user: 939
    - group: 939
    - makedirs: True

strelkalogdir:
  file.directory:
    - name: /nsm/strelka/log
    - user: 939
    - group: 939
    - makedirs: True

strelkaprocessed:
  file.directory:
    - name: /nsm/strelka/processed
    - user: 939
    - group: 939
    - makedirs: True

strelkastaging:
  file.directory:
    - name: /nsm/strelka/staging
    - user: 939
    - group: 939
    - makedirs: True

strelkaunprocessed:
  file.directory:
    - name: /nsm/strelka/unprocessed
    - user: 939
    - group: 939
    - mode: 775
    - makedirs: True

# Check to see if Strelka frontend port is available
strelkaportavailable:
  cmd.run:
    - name: netstat -utanp | grep ":57314" | grep -qvE 'docker|TIME_WAIT' && PROCESS=$(netstat -utanp | grep ":57314" | uniq) && echo "Another process ($PROCESS) appears to be using port 57314.  Please terminate this process, or reboot to ensure a clean state so that Strelka can start properly." && exit 1 || exit 0

# Filecheck Section
filecheck_logdir:
  file.directory:
    - name: /opt/tc/log/strelka
    - user: 939
    - group: 939
    - mode: 775
    - makedirs: True
    
filecheck_history:
  file.directory:
    - name: /nsm/strelka/history
    - user: 939
    - group: 939
    - mode: 775
    - makedirs: True

filecheck_conf:
  file.managed:
    - name: /opt/tc/conf/strelka/filecheck.yaml
    - source: salt://strelka/filecheck/filecheck.yaml
    - template: jinja

filecheck_script:
  file.managed:
    - name: /opt/tc/conf/strelka/filecheck
    - source: salt://strelka/filecheck/filecheck
    - user: 939
    - group: 939
    - mode: 755

filecheck_restart:
  cmd.run:
    - name: pkill -f "python3 /opt/tc/conf/strelka/filecheck"
    - hide_output: True
    - success_retcodes: [0,1]
    - onchanges:
      - file: filecheck_script

filecheck_oldcronremoval:
  cron.absent:
    - name: 'ps -ef | grep filecheck | grep -v grep || python3 /opt/tc/conf/strelka/filecheck >> /opt/tc/log/strelka/filecheck_stdout.log 2>&1 &'
    - user: {{ filecheck_runas }}

filecheck_run:
  cron.present:
    - name: 'ps -ef | grep filecheck | grep -v grep > /dev/null 2>&1 || python3 /opt/tc/conf/strelka/filecheck >> /opt/tc/log/strelka/filecheck_stdout.log 2>&1 &'
    - user: {{ filecheck_runas }}

filcheck_history_clean:
  cron.present:
    - name: '/usr/bin/find /nsm/strelka/history/ -type f -mtime +2 -exec rm {} + > /dev/null 2>&1'
    - minute: '33'
# End Filecheck Section

strelkagkredisdatadir:
  file.directory:
    - name: /nsm/strelka/gk-redis-data
    - user: 939
    - group: 939
    - makedirs: True

strelkacoordredisdatadir:
  file.directory:
    - name: /nsm/strelka/coord-redis-data
    - user: 939
    - group: 939
    - makedirs: True

strelka_coordinator:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-redis:{{ VERSION }}
    - binds:
      - /nsm/strelka/coord-redis-data:/data:rw
    - name: tc-strelka-coordinator
    - entrypoint: redis-server --save "" --appendonly no
    - port_bindings:
      - 0.0.0.0:6380:6379

append_tc-strelka-coordinator_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-strelka-coordinator

strelka_gatekeeper:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-redis:{{ VERSION }}
    - binds:
      - /nsm/strelka/gk-redis-data:/data:rw
    - name: tc-strelka-gatekeeper
    - entrypoint: redis-server --save "" --appendonly no --maxmemory-policy allkeys-lru
    - port_bindings:
      - 0.0.0.0:6381:6379

append_tc-strelka-gatekeeper_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-strelka-gatekeeper

strelka_frontend:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-strelka-frontend:{{ VERSION }}
    - binds:
      - /opt/tc/conf/strelka/frontend/:/etc/strelka/:ro
      - /nsm/strelka/log/:/var/log/strelka/:rw
    - privileged: True
    - name: tc-strelka-frontend
    - command: strelka-frontend
    - port_bindings:
      - 0.0.0.0:57314:57314

append_tc-strelka-frontend_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-strelka-frontend

strelka_backend:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-strelka-backend:{{ VERSION }}
    - binds:
      - /opt/tc/conf/strelka/backend/:/etc/strelka/:ro
      - /opt/tc/conf/strelka/rules/:/etc/yara/:ro
    - name: tc-strelka-backend
    - command: strelka-backend
    - restart_policy: on-failure

append_tc-strelka-backend_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-strelka-backend

strelka_manager:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-strelka-manager:{{ VERSION }}
    - binds:
      - /opt/tc/conf/strelka/manager/:/etc/strelka/:ro
    - name: tc-strelka-manager
    - command: strelka-manager

append_tc-strelka-manager_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-strelka-manager

strelka_filestream:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-strelka-filestream:{{ VERSION }}
    - binds:
      - /opt/tc/conf/strelka/filestream/:/etc/strelka/:ro
      - /nsm/strelka:/nsm/strelka
    - name: tc-strelka-filestream
    - command: strelka-filestream

append_tc-strelka-filestream_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-strelka-filestream

strelka_zeek_extracted_sync_old:
  cron.absent:
    - user: root
    - name: '[ -d /nsm/zeek/extracted/complete/ ] && mv /nsm/zeek/extracted/complete/* /nsm/strelka/ > /dev/null 2>&1'
    - minute: '*'

{% if ENGINE == "SURICATA" %}

strelka_suricata_extracted_sync:
  cron.absent:
    - user: root
    - identifier: zeek-extracted-strelka-sync
    - name: '[ -d /nsm/suricata/extracted/ ] && find /nsm/suricata/extracted/* -not \( -path /nsm/suricata/extracted/tmp -prune \) -type f -print0 | xargs -0 -I {} mv {} /nsm/strelka/unprocessed/ > /dev/null 2>&1'
    - minute: '*'

{% else %}
strelka_zeek_extracted_sync:
  cron.absent:
    - user: root
    - identifier: zeek-extracted-strelka-sync
    - name: '[ -d /nsm/zeek/extracted/complete/ ] && mv /nsm/zeek/extracted/complete/* /nsm/strelka/unprocessed/ > /dev/null 2>&1'
    - minute: '*'

{% endif %}
{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
