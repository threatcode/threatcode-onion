# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://threatcode.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls.split('.')[0] in allowed_states %}
{%   from 'vars/globals.map.jinja' import GLOBALS %}
{%   from 'docker/docker.map.jinja' import DOCKER %}


include:
  - zeek.config
  - zeek.sostatus

so-zeek:
  docker_container.running:
    - image: {{ GLOBALS.registry_host }}:5000/{{ GLOBALS.image_repo }}/so-zeek:{{ GLOBALS.so_version }}
    - start: True
    - privileged: True
    - ulimits:
      - core=0
      - nofile=1048576:1048576
    - binds:
      - /nsm/zeek/logs:/nsm/zeek/logs:rw
      - /nsm/zeek/spool:/nsm/zeek/spool:rw
      - /nsm/zeek/extracted:/nsm/zeek/extracted:rw
      - /opt/tc/conf/zeek/local.zeek:/opt/zeek/share/zeek/site/local.zeek:ro
      - /opt/tc/conf/zeek/node.cfg:/opt/zeek/etc/node.cfg:ro
      - /opt/tc/conf/zeek/networks.cfg:/opt/zeek/etc/networks.cfg:ro
      - /opt/tc/conf/zeek/zeekctl.cfg:/opt/zeek/etc/zeekctl.cfg:ro
      - /opt/tc/conf/zeek/policy/threatcode:/opt/zeek/share/zeek/policy/threatcode:ro
      - /opt/tc/conf/zeek/policy/custom:/opt/zeek/share/zeek/policy/custom:ro
      - /opt/tc/conf/zeek/policy/cve-2020-0601:/opt/zeek/share/zeek/policy/cve-2020-0601:ro
      - /opt/tc/conf/zeek/policy/intel:/opt/zeek/share/zeek/policy/intel:rw
      - /opt/tc/conf/zeek/bpf:/opt/zeek/etc/bpf:ro
      {% if DOCKER.containers['so-zeek'].custom_bind_mounts %}
        {% for BIND in DOCKER.containers['so-zeek'].custom_bind_mounts %}
      - {{ BIND }}
        {% endfor %}
      {% endif %} 
    - network_mode: host
    {% if DOCKER.containers['so-zeek'].extra_hosts %}
    - extra_hosts:
      {% for XTRAHOST in DOCKER.containers['so-zeek'].extra_hosts %}
      - {{ XTRAHOST }}
      {% endfor %}
    {% endif %}
    {% if DOCKER.containers['so-zeek'].extra_env %}
    - environment:
      {% for XTRAENV in DOCKER.containers['so-zeek'].extra_env %}
      - {{ XTRAENV }}
      {% endfor %}
    {% endif %}
    - watch:
      - file: /opt/tc/conf/zeek/local.zeek
      - file: /opt/tc/conf/zeek/node.cfg
      - file: /opt/tc/conf/zeek/networks.cfg
      - file: /opt/tc/conf/zeek/zeekctl.cfg
      - file: /opt/tc/conf/zeek/policy
      - file: /opt/tc/conf/zeek/bpf
    - require:
      - file: localzeek
      - file: nodecfg
      - file: zeekctlcfg
      - file: zeekbpf

delete_so-zeek_so-status.disabled:
  file.uncomment:
    - name: /opt/tc/conf/so-status/so-status.conf
    - regex: ^so-zeek$

zeekpacketlosscron:
  cron.present:
    - name: /usr/local/bin/packetloss.sh
    - identifier: zeekpacketlosscron
    - user: root
    - minute: '*/10'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
