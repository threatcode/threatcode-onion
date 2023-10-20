# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://threatcode.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls.split('.')[0] in allowed_states %}

include:
  - influxdb.sostatus
  
so-influxdb:
  docker_container.absent:
    - force: True

so-influxdb_so-status.disabled:
  file.comment:
    - name: /opt/tc/conf/so-status/so-status.conf
    - regex: ^so-influxdb$

get_influxdb_size:
  cron.absent:
    - identifier: get_influxdb_size
    - user: root

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
