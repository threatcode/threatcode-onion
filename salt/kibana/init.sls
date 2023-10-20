{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% from 'elasticsearch/auth.map.jinja' import ELASTICAUTH with context %}

{% import_yaml 'kibana/defaults.yaml' as default_settings %}
{% set KIBANA_SETTINGS = salt['grains.filter_by'](default_settings, default='kibana', merge=salt['pillar.get']('kibana', {})) %}

{% from 'kibana/config.map.jinja' import KIBANACONFIG with context %}

# Add ES Group
kibanasearchgroup:
  group.present:
    - name: kibana
    - gid: 932

# Add ES user
kibana:
  user.present:
    - uid: 932
    - gid: 932
    - home: /opt/tc/conf/kibana
    - createhome: False

# Drop the correct nginx config based on role

kibanaconfdir:
  file.directory:
    - name: /opt/tc/conf/kibana/etc
    - user: 932
    - group: 939
    - makedirs: True

kibanaconfig:
  file.managed:
    - name: /opt/tc/conf/kibana/etc/kibana.yml
    - source: salt://kibana/etc/kibana.yml.jinja
    - user: 932
    - group: 939
    - mode: 660
    - template: jinja
    - defaults:
        KIBANACONFIG: {{ KIBANACONFIG }}
    - show_changes: False

kibanalogdir:
  file.directory:
    - name: /opt/tc/log/kibana
    - user: 932
    - group: 939
    - makedirs: True

kibanacustdashdir:
  file.directory:
    - name: /opt/tc/conf/kibana/customdashboards
    - user: 932
    - group: 939
    - makedirs: True

synckibanacustom:
  file.recurse:
    - name: /opt/tc/conf/kibana/customdashboards
    - source: salt://kibana/custom
    - user: 932
    - group: 939

kibanabin:
  file.managed:
    - name: /usr/sbin/tc-kibana-config-load
    - source: salt://kibana/bin/tc-kibana-config-load
    - mode: 755
    - template: jinja
    - defaults:
        ELASTICCURL: {{ ELASTICAUTH.elasticcurl }}

# Start the kibana docker
tc-kibana:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-kibana:{{ VERSION }}
    - hostname: kibana
    - user: kibana
    - environment:
      - ELASTICSEARCH_HOST={{ MANAGER }}
      - ELASTICSEARCH_PORT=9200
      - MANAGER={{ MANAGER }}
    - binds:
      - /opt/tc/conf/kibana/etc:/usr/share/kibana/config:rw
      - /opt/tc/log/kibana:/var/log/kibana:rw
      - /opt/tc/conf/kibana/customdashboards:/usr/share/kibana/custdashboards:ro
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    - port_bindings:
      - 0.0.0.0:5601:5601
    - watch:
      - file: kibanaconfig

append_tc-kibana_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-kibana

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
