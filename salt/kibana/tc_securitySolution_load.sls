include:
  - kibana

securitySolution_saved_objects:
  file.managed:
    - name: /opt/tc/conf/kibana/securitySolution_saved_objects.ndjson.template
    - source: salt://kibana/files/securitySolution_saved_objects.ndjson
    - user: 932
    - group: 939

securitySolution_saved_objects_changes:
  file.absent:
    - names:
      - /opt/tc/state/kibana_config_saved_objects.txt
    - onchanges:
      - file: securitySolution_saved_objects

tc-kibana-securitySolution_saved_objects-load:
  cmd.run:
    - name: /usr/sbin/tc-kibana-config-load -u /opt/tc/conf/kibana/securitySolution_saved_objects.ndjson.template
    - cwd: /opt/so
    - require:
      - sls: kibana
      - file: securitySolution_saved_objects
