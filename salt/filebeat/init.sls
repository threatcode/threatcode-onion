
# Copyright 2014-2023 Threat Code Solutions, LLC
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
{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set LOCALHOSTNAME = salt['grains.get']('host') %}
{% set MANAGER = salt['grains.get']('master') %}
{% from 'filebeat/modules.map.jinja' import MODULESMERGED with context %}
{% from 'filebeat/modules.map.jinja' import MODULESENABLED with context %}
{% from 'filebeat/map.jinja' import FILEBEAT_EXTRA_HOSTS with context %}
{% set ES_INCLUDED_NODES = ['tc-eval', 'tc-standalone', 'tc-managersearch', 'tc-node', 'tc-heavynode', 'tc-import'] %}

include:
  - ssl
#only include elastic state for certain nodes
{% if grains.role in ES_INCLUDED_NODES %}
  - elasticsearch
{% endif %}

filebeatetcdir:
  file.directory:
    - name: /opt/tc/conf/filebeat/etc
    - user: 939
    - group: 939
    - makedirs: True

filebeatmoduledir:
  file.directory:
    - name: /opt/tc/conf/filebeat/modules
    - user: root
    - group: root
    - makedirs: True

filebeatlogdir:
  file.directory:
    - name: /opt/tc/log/filebeat
    - user: 939
    - group: 939
    - makedirs: True

filebeatpkidir:
  file.directory:
    - name: /opt/tc/conf/filebeat/etc/pki
    - user: 939
    - group: 939
    - makedirs: True
fileregistrydir:
  file.directory:
    - name: /opt/tc/conf/filebeat/registry
    - user: 939
    - group: 939
    - makedirs: True

# This needs to be owned by root
filebeatconf:
  file.managed:
    - name: /opt/tc/conf/filebeat/etc/filebeat.yml
    - source: salt://filebeat/etc/filebeat.yml
    - user: root
    - group: root
    - template: jinja
    - defaults:
        INPUTS: {{ salt['pillar.get']('filebeat:config:inputs', {}) }}
        OUTPUT: {{ salt['pillar.get']('filebeat:config:output', {}) }}
    - show_changes: False

# Filebeat module config file
filebeatmoduleconf:
  file.managed:
    - name: /opt/tc/conf/filebeat/etc/module-setup.yml
    - source: salt://filebeat/etc/module-setup.yml
    - user: root
    - group: root
    - mode: 640
    - template: jinja
    - show_changes: False

merged_module_conf:
  file.managed:
    - name: /opt/tc/conf/filebeat/modules/modules.yml
    - source: salt://filebeat/etc/module_config.yml.jinja
    - template: jinja
    - defaults:
        MODULES: {{ MODULESENABLED }}

tc_module_conf_remove:
  file.absent:
    - name: /opt/tc/conf/filebeat/modules/threatcode.yml

thirdyparty_module_conf_remove:
  file.absent:
    - name: /opt/tc/conf/filebeat/modules/thirdparty.yml
    
tc-filebeat:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-filebeat:{{ VERSION }}
    - hostname: tc-filebeat
    - user: root
    - extra_hosts: {{ FILEBEAT_EXTRA_HOSTS }}
    - binds:
      - /nsm:/nsm:ro
      - /opt/tc/log/filebeat:/usr/share/filebeat/logs:rw
      - /opt/tc/conf/filebeat/etc/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /opt/tc/conf/filebeat/etc/module-setup.yml:/usr/share/filebeat/module-setup.yml:ro
      - /nsm/wazuh/logs/alerts:/wazuh/alerts:ro
      - /nsm/wazuh/logs/archives:/wazuh/archives:ro
      - /opt/tc/conf/filebeat/modules:/usr/share/filebeat/modules.d
      - /opt/tc/conf/filebeat/etc/pki/filebeat.crt:/usr/share/filebeat/filebeat.crt:ro
      - /opt/tc/conf/filebeat/etc/pki/filebeat.key:/usr/share/filebeat/filebeat.key:ro
      - /opt/tc/conf/filebeat/registry:/usr/share/filebeat/data/registry:rw
      - /etc/ssl/certs/intca.crt:/usr/share/filebeat/intraca.crt:ro
      - /opt/tc/log:/logs:ro
    - port_bindings:
        - 0.0.0.0:514:514/udp
        - 0.0.0.0:514:514/tcp
        - 0.0.0.0:5066:5066/tcp
{% for module in MODULESMERGED.modules.keys() %}
  {% for submodule in MODULESMERGED.modules[module] %}
    {% if MODULESMERGED.modules[module][submodule].enabled and MODULESMERGED.modules[module][submodule]["var.syslog_port"] is defined %}
        - {{ MODULESMERGED.modules[module][submodule].get("var.syslog_host", "0.0.0.0") }}:{{ MODULESMERGED.modules[module][submodule]["var.syslog_port"] }}:{{ MODULESMERGED.modules[module][submodule]["var.syslog_port"] }}/tcp
        - {{ MODULESMERGED.modules[module][submodule].get("var.syslog_host", "0.0.0.0") }}:{{ MODULESMERGED.modules[module][submodule]["var.syslog_port"] }}:{{ MODULESMERGED.modules[module][submodule]["var.syslog_port"] }}/udp
    {% endif %}
  {% endfor %}
{% endfor %}
    - watch:
      - file: filebeatconf
    - require:
      - file: filebeatconf
      - file: filebeatmoduleconf
      - file: filebeatmoduledir
      - x509: conf_filebeat_crt
      - x509: conf_filebeat_key
      - x509: trusttheca

{% if grains.role in ES_INCLUDED_NODES %}
run_module_setup:
  cmd.run:
    - name: /usr/sbin/tc-filebeat-module-setup
    - require:
      - file: filebeatmoduleconf
      - docker_container: tc-filebeat
    - onchanges:
      - docker_container: tc-elasticsearch
{% endif %}

append_tc-filebeat_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-filebeat

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
