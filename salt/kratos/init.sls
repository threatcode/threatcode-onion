{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}

# Add Kratos Group
kratosgroup:
  group.present:
    - name: kratos
    - gid: 928

# Add Kratos user
kratos:
  user.present:
    - uid: 928
    - gid: 928
    - home: /opt/tc/conf/kratos
    
kratosdir:
  file.directory:
    - name: /nsm/kratos
    - user: 928
    - group: 928
    - mode: 700
    - makedirs: True

kratosdbdir:
  file.directory:
    - name: /nsm/kratos/db
    - user: 928
    - group: 928
    - mode: 700
    - makedirs: True

kratoslogdir:
  file.directory:
    - name: /opt/tc/log/kratos
    - user: 928
    - group: 928
    - makedirs: True

kratossync:
  file.recurse:
    - name: /opt/tc/conf/kratos
    - source: salt://kratos/files
    - user: 928
    - group: 928
    - file_mode: 600
    - template: jinja

kratos_schema:
  file.exists:
    - name: /opt/tc/conf/kratos/schema.json
  
kratos_yaml:
  file.exists:
    - name: /opt/tc/conf/kratos/kratos.yaml

tc-kratos:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-kratos:{{ VERSION }}
    - hostname: kratos
    - name: tc-kratos
    - binds:
      - /opt/tc/conf/kratos/schema.json:/kratos-conf/schema.json:ro    
      - /opt/tc/conf/kratos/kratos.yaml:/kratos-conf/kratos.yaml:ro
      - /opt/tc/log/kratos/:/kratos-log:rw
      - /nsm/kratos/db:/kratos-data:rw
    - port_bindings:
      - 0.0.0.0:4433:4433
      - 0.0.0.0:4434:4434
    - restart_policy: unless-stopped
    - watch:
      - file: /opt/tc/conf/kratos
    - require:
      - file: kratos_schema
      - file: kratos_yaml
      - file: kratoslogdir
      - file: kratosdir

append_tc-kratos_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-kratos

wait_for_kratos:
  http.wait_for_successful_query:
    - name: 'http://{{ MANAGER }}:4434/'
    - ssl: True
    - verify_ssl: False
    - status:
      - 200
      - 301
      - 302
      - 404
    - status_type: list
    - wait_for: 300
    - request_interval: 10
    - require:
      -  docker_container: tc-kratos

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
