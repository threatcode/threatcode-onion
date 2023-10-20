{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% set logscan_cpu_period = salt['pillar.get']('learn:modules:logscan:cpu_period', 20000) %}
{% set enabled = salt['pillar.get']('learn:modules:logscan:enabled', False) %}

{% if enabled %}
  {% set container_action = 'running' %}
{% else %}
  {% set container_action = 'absent'%}
{% endif %}


logscan_data_dir:
  file.directory:
    - name: /nsm/logscan/data
    - user: 939
    - group: 939
    - makedirs: True

logscan_conf_dir:
  file.directory:
    - name: /opt/tc/conf/logscan
    - user: 939
    - group: 939
    - makedirs: True

logscan_conf:
  file.managed:
    - name: /opt/tc/conf/logscan/logscan.conf
    - source: salt://learn/files/logscan.conf
    - user: 939
    - group: 939
    - mode: 600

logscan_log_dir:
  file.directory:
    - name: /opt/tc/log/logscan
    - user: 939
    - group: 939

tc-logscan:
  docker_container.{{ container_action }}:
    {% if container_action == 'running' %}
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-logscan:{{ VERSION }}
    - hostname: logscan
    - name: tc-logscan
    - binds:
      - /nsm/logscan/data:/logscan/data:rw
      - /opt/tc/conf/logscan/logscan.conf:/logscan/logscan.conf:ro
      - /opt/tc/log/logscan:/logscan/output:rw
      - /opt/tc/log:/logscan/logs:ro
    - cpu_period: {{ logscan_cpu_period }}
    - require:
      - file: logscan_conf
    {% else %}
    - force: true
    {% endif %}
