include:
  - kibana

config_saved_objects:
  file.managed:
    - name: /opt/tc/conf/kibana/config_saved_objects.ndjson.template
    - source: salt://kibana/files/config_saved_objects.ndjson
    - user: 932
    - group: 939

config_saved_objects_changes:
  file.absent:
    - names:
      - /opt/tc/state/kibana_config_saved_objects.txt
    - onchanges:
      - file: config_saved_objects

tc-kibana-config-load:
  cmd.run:
    - name: /usr/sbin/tc-kibana-config-load -i /opt/tc/conf/kibana/config_saved_objects.ndjson.template
    - cwd: /opt/so
    - require:
      - sls: kibana
      - file: config_saved_objects
