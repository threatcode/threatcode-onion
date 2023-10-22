# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at
# https://threatcode.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls.split('.')[0] in allowed_states %}
{%   from 'vars/globals.map.jinja' import GLOBALS %}
{%   from 'docker/docker.map.jinja' import DOCKER %}
{%   from 'soc/merged.map.jinja' import DOCKER_EXTRA_HOSTS %}

include:
  - soc.config
  - soc.sostatus

so-soc:
  docker_container.running:
    - image: {{ GLOBALS.registry_host }}:5000/{{ GLOBALS.image_repo }}/so-soc:{{ GLOBALS.so_version }}
    - hostname: soc
    - name: tc-soc
    - networks:
      - sobridge:
        - ipv4_address: {{ DOCKER.containers['so-soc'].ip }}
    - binds:
      - /nsm/soc/jobs:/opt/sensoroni/jobs:rw
      - /nsm/soc/uploads:/nsm/soc/uploads:rw
      - /opt/tc/log/soc/:/opt/sensoroni/logs/:rw
      - /opt/tc/conf/soc/soc.json:/opt/sensoroni/sensoroni.json:ro
      - /opt/tc/conf/soc/motd.md:/opt/sensoroni/html/motd.md:ro
      - /opt/tc/conf/soc/banner.md:/opt/sensoroni/html/login/banner.md:ro
      - /opt/tc/conf/soc/custom.js:/opt/sensoroni/html/js/custom.js:ro
      - /opt/tc/conf/soc/custom_roles:/opt/sensoroni/rbac/custom_roles:ro
      - /opt/tc/conf/soc/soc_users_roles:/opt/sensoroni/rbac/users_roles:rw
      - /opt/tc/conf/soc/queue:/opt/sensoroni/queue:rw
      - /opt/tc/saltstack:/opt/tc/saltstack:rw
    - extra_hosts: {{ DOCKER_EXTRA_HOSTS }}
      {% if DOCKER.containers['so-soc'].extra_hosts %}
        {% for XTRAHOST in DOCKER.containers['so-soc'].extra_hosts %}
      - {{ XTRAHOST }}
        {% endfor %}
      {% endif %}
    - port_bindings:
      {% for BINDING in DOCKER.containers['so-soc'].port_bindings %}
      - {{ BINDING }}
      {% endfor %}
    {% if DOCKER.containers['so-soc'].extra_env %}
    - environment:
      {% for XTRAENV in DOCKER.containers['so-soc'].extra_env %}
      - {{ XTRAENV }}
      {% endfor %}
    {% endif %}
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

delete_so-soc_so-status.disabled:
  file.uncomment:
    - name: /opt/tc/conf/so-status/so-status.conf
    - regex: ^so-soc$

salt-relay:
  cron.present:
    - name: '/opt/tc/saltstack/default/salt/soc/files/bin/salt-relay.sh &'
    - identifier: salt-relay

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
