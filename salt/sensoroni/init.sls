{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}

sensoroniconfdir:
  file.directory:
    - name: /opt/tc/conf/sensoroni
    - user: 939
    - group: 939
    - makedirs: True

sensoroniagentconf:
  file.managed:
    - name: /opt/tc/conf/sensoroni/sensoroni.json
    - source: salt://sensoroni/files/sensoroni.json
    - user: 939
    - group: 939
    - mode: 600
    - template: jinja

analyzersdir:
  file.directory:
    - name: /opt/tc/conf/sensoroni/analyzers
    - user: 939
    - group: 939
    - makedirs: True

sensoronilog:
  file.directory:
    - name: /opt/tc/log/sensoroni
    - user: 939
    - group: 939
    - makedirs: True

analyzerscripts:
  file.recurse:
    - name: /opt/tc/conf/sensoroni/analyzers
    - user: 939
    - group: 939
    - file_mode: 755
    - template: jinja
    - source: salt://sensoroni/files/analyzers

tc-sensoroni:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-soc:{{ VERSION }}
    - network_mode: host
    - binds:
      - /opt/tc/conf/steno/certs:/etc/stenographer/certs:rw
      - /nsm/pcap:/nsm/pcap:rw
      - /nsm/import:/nsm/import:rw
      - /nsm/pcapout:/nsm/pcapout:rw
      - /opt/tc/conf/sensoroni/sensoroni.json:/opt/sensoroni/sensoroni.json:ro
      - /opt/tc/conf/sensoroni/analyzers:/opt/sensoroni/analyzers:rw
      - /opt/tc/log/sensoroni:/opt/sensoroni/logs:rw
    - watch:
      - file: /opt/tc/conf/sensoroni/sensoroni.json
    - require:
      - file: sensoroniagentconf

append_tc-sensoroni_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-sensoroni
