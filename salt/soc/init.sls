{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}

include:
  - manager.sync_es_users

socdir:
  file.directory:
    - name: /opt/tc/conf/soc
    - user: 939
    - group: 939
    - makedirs: True

socdatadir:
  file.directory:
    - name: /nsm/soc/jobs
    - user: 939
    - group: 939
    - makedirs: True

soclogdir:
  file.directory:
    - name: /opt/tc/log/soc
    - user: 939
    - group: 939
    - makedirs: True

socactions:
  file.managed:
    - name: /opt/tc/conf/soc/menu.actions.json
    - source: salt://soc/files/soc/menu.actions.json
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja

socconfig:
  file.managed:
    - name: /opt/tc/conf/soc/soc.json
    - source: salt://soc/files/soc/soc.json
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja
    - show_changes: False

socmotd:
  file.managed:
    - name: /opt/tc/conf/soc/motd.md
    - source: salt://soc/files/soc/motd.md
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja

socbanner:
  file.managed:
    - name: /opt/tc/conf/soc/banner.md
    - source: salt://soc/files/soc/banner.md
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja

soccustom:
  file.managed:
    - name: /opt/tc/conf/soc/custom.js
    - source: salt://soc/files/soc/custom.js
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja

soccustomroles:
  file.managed:
    - name: /opt/tc/conf/soc/custom_roles
    - source: salt://soc/files/soc/custom_roles
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja

socusersroles:
  file.exists:
    - name: /opt/tc/conf/soc/soc_users_roles
    - require:
      - sls: manager.sync_es_users

tc-soc:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-soc:{{ VERSION }}
    - hostname: soc
    - name: tc-soc
    - binds:
      - /nsm/soc/jobs:/opt/sensoroni/jobs:rw
      - /opt/tc/log/soc/:/opt/sensoroni/logs/:rw
      - /opt/tc/conf/soc/soc.json:/opt/sensoroni/sensoroni.json:ro
      - /opt/tc/conf/soc/motd.md:/opt/sensoroni/html/motd.md:ro
      - /opt/tc/conf/soc/banner.md:/opt/sensoroni/html/login/banner.md:ro
      - /opt/tc/conf/soc/custom.js:/opt/sensoroni/html/js/custom.js:ro
      - /opt/tc/conf/soc/custom_roles:/opt/sensoroni/rbac/custom_roles:ro
      - /opt/tc/conf/soc/soc_users_roles:/opt/sensoroni/rbac/users_roles:rw
    {%- if salt['pillar.get']('nodestab', {}) %}
    - extra_hosts:
      {%- for SN, SNDATA in salt['pillar.get']('nodestab', {}).items() %}
      - {{ SN.split('_')|first }}:{{ SNDATA.ip }}
      {%- endfor %}
      {%- endif %}
    - port_bindings:
      - 0.0.0.0:9822:9822
    - watch:
      - file: /opt/tc/conf/soc/*
    - require:
      - file: socdatadir
      - file: soclogdir
      - file: socconfig
      - file: socmotd
      - file: socbanner
      - file: soccustom
      - file: soccustomroles
      - file: socusersroles

append_tc-soc_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-soc

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
