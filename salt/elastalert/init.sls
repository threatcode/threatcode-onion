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

{% from 'elastalert/elastalert_config.map.jinja' import elastalert_defaults as elastalert_config with context %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{%- set MANAGER_URL = salt['pillar.get']('global:url_base', '') %}
{%- set MANAGER_IP = salt['pillar.get']('global:managerip', '') %}

{% if grains['role'] in ['tc-eval','tc-managersearch', 'tc-manager', 'tc-standalone'] %}
  {% set esalert = salt['pillar.get']('manager:elastalert', '1') %}
  {% set esip = salt['pillar.get']('manager:mainip', '') %}
  {% set esport = salt['pillar.get']('manager:es_port', '') %}
{% elif grains['role'] == 'tc-node' %}
  {% set esalert = salt['pillar.get']('elasticsearch:elastalert', '0') %}
{% endif %}

# Elastalert
{% if esalert == 1 %}

# Create the group
elastagroup:
  group.present:
    - name: elastalert
    - gid: 933

# Add user
elastalert:
  user.present:
    - uid: 933
    - gid: 933
    - home: /opt/tc/conf/elastalert
    - createhome: False

elastalogdir:
  file.directory:
    - name: /opt/tc/log/elastalert
    - user: 933
    - group: 933
    - makedirs: True

elastarules:
  file.directory:
    - name: /opt/tc/rules/elastalert
    - user: 933
    - group: 933
    - makedirs: True

elastaconfdir:
  file.directory:
    - name: /opt/tc/conf/elastalert
    - user: 933
    - group: 933
    - makedirs: True

elastasomodulesdir:
  file.directory:
    - name: /opt/tc/conf/elastalert/modules/so
    - user: 933
    - group: 933
    - makedirs: True

elastacustmodulesdir:
  file.directory:
    - name: /opt/tc/conf/elastalert/modules/custom
    - user: 933
    - group: 933
    - makedirs: True

elastasomodulesync:
  file.recurse:
    - name: /opt/tc/conf/elastalert/modules/so
    - source: salt://elastalert/files/modules/so
    - user: 933
    - group: 933
    - makedirs: True

elastaconf:
  file.managed:
    - name: /opt/tc/conf/elastalert/elastalert_config.yaml
    - source: salt://elastalert/files/elastalert_config.yaml.jinja
    - context:
        elastalert_config: {{ elastalert_config.elastalert.config }}
    - user: 933
    - group: 933
    - mode: 660
    - template: jinja
    - show_changes: False

wait_for_elasticsearch:
  cmd.run:
    - name: tc-elasticsearch-wait

tc-elastalert:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-elastalert:{{ VERSION }}
    - hostname: elastalert
    - name: tc-elastalert
    - user: tc-elastalert
    - detach: True
    - binds:
      - /opt/tc/rules/elastalert:/opt/elastalert/rules/:ro
      - /opt/tc/log/elastalert:/var/log/elastalert:rw
      - /opt/tc/conf/elastalert/modules/:/opt/elastalert/modules/:ro
      - /opt/tc/conf/elastalert/elastalert_config.yaml:/opt/elastalert/config.yaml:ro
    - extra_hosts:
      - {{MANAGER_URL}}:{{MANAGER_IP}}
    - require:
      - cmd: wait_for_elasticsearch
      - file: elastarules
      - file: elastalogdir
      - file: elastacustmodulesdir
      - file: elastaconf
    - watch:
      - file: elastaconf
    - onlyif:
      - "tc-elasticsearch-query / | jq -r '.version.number[0:1]' | grep -q 8" {# only run this state if elasticsearch is version 8 #}


append_tc-elastalert_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-elastalert

{% endif %}

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
