# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://threatcode.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls.split('.')[0] in allowed_states %}
{%   from 'influxdb/map.jinja' import INFLUXMERGED %}

include:
  - salt.minion
  - ssl
  
# Influx DB
influxconfdir:
  file.directory:
    - name: /opt/tc/conf/influxdb
    - makedirs: True

influxlogdir:
  file.directory:
    - name: /opt/tc/log/influxdb
    - dir_mode: 755
    - user: 939
    - group: 939
    - makedirs: True

influxetcdir:
  file.directory:
    - name: /opt/tc/conf/influxdb/etc
    - dir_mode: 750
    - user: 939
    - group: 939
    - makedirs: True

influxdbdir:
  file.directory:
    - name: /nsm/influxdb
    - makedirs: True

influxdb_sbin:
  file.recurse:
    - name: /usr/sbin
    - source: salt://influxdb/tools/sbin
    - user: 939
    - group: 939
    - file_mode: 755

#influxdb_sbin_jinja:
#  file.recurse:
#    - name: /usr/sbin
#    - source: salt://influxdb/tools/sbin_jinja
#    - user: 939
#    - group: 939 
#    - file_mode: 755
#    - template: jinja

influxdbconf:
  file.managed:
    - name: /opt/tc/conf/influxdb/config.yaml
    - source: salt://influxdb/config.yaml.jinja
    - user: 939
    - group: 939
    - template: jinja
    - defaults:
        INFLUXMERGED: {{ INFLUXMERGED }}

influxdbbucketsconf:
  file.managed:
    - name: /opt/tc/conf/influxdb/buckets.json
    - source: salt://influxdb/buckets.json.jinja
    - user: 939
    - group: 939
    - template: jinja
    - defaults:
        INFLUXMERGED: {{ INFLUXMERGED }}

influxdb-templates:
  file.recurse:
    - name: /opt/tc/conf/influxdb/templates
    - source: salt://influxdb/templates
    - user: 939
    - group: 939
    - template: jinja
    - clean: True
    - defaults:
        INFLUXMERGED: {{ INFLUXMERGED }}

influxdb_curl_config:
  file.managed:
    - name: /opt/tc/conf/influxdb/curl.config
    - source: salt://influxdb/curl.config.jinja
    - mode: 600
    - template: jinja
    - show_changes: False
    - makedirs: True

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
