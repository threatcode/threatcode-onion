{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% set MANAGER_URL = salt['pillar.get']('global:url_base', '') %}
{% set MANAGER_IP = salt['pillar.get']('global:managerip', '') %}
{% set ISAIRGAP = salt['pillar.get']('global:airgap', 'False') %}

include:
  - nginx

soctopusdir:
  file.directory:
    - name: /opt/tc/conf/soctopus/sigma-import
    - user: 939
    - group: 939
    - makedirs: True

soctopus-sync:
  file.recurse:
    - name: /opt/tc/conf/soctopus/templates
    - source: salt://soctopus/files/templates
    - user: 939
    - group: 939
    - template: jinja

soctopusconf:
  file.managed:
    - name: /opt/tc/conf/soctopus/SOCtopus.conf
    - source: salt://soctopus/files/SOCtopus.conf
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja
    - show_changes: False

soctopuslogdir:
  file.directory:
    - name: /opt/tc/log/soctopus
    - user: 939
    - group: 939

playbookrulesdir:
  file.directory:
    - name: /opt/tc/rules/elastalert/playbook
    - user: 939
    - group: 939
    - makedirs: True

playbookrulessync:
  file.recurse:
    - name: /opt/tc/rules/elastalert/playbook
    - source: salt://soctopus/files/templates
    - user: 939
    - group: 939
    - template: jinja

tc-soctopus:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-soctopus:{{ VERSION }}
    - hostname: soctopus
    - name: tc-soctopus
    - binds:
      - /opt/tc/conf/soctopus/SOCtopus.conf:/SOCtopus/SOCtopus.conf:ro
      - /opt/tc/log/soctopus/:/var/log/SOCtopus/:rw
      - /opt/tc/rules/elastalert/playbook:/etc/playbook-rules:rw
      - /opt/tc/conf/navigator/layers/:/etc/playbook/:rw
      - /opt/tc/conf/soctopus/sigma-import/:/SOCtopus/sigma-import/:rw    
      {% if ISAIRGAP is sameas true %}
      - /nsm/repo/rules/sigma:/soctopus/sigma
      {% endif %}
    - port_bindings:
      - 0.0.0.0:7000:7000
    - extra_hosts:
      - {{MANAGER_URL}}:{{MANAGER_IP}}
    - require:
      - file: soctopusconf
      - file: navigatordefaultlayer

append_tc-soctopus_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-soctopus

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
