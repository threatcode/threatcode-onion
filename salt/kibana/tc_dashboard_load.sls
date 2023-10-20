{% set HIGHLANDER = salt['pillar.get']('global:highlander', False) %}
include:
  - kibana

dashboard_saved_objects_template:
  file.managed:
    - name: /opt/tc/conf/kibana/saved_objects.ndjson.template
    - source: salt://kibana/files/saved_objects.ndjson
    - user: 932
    - group: 939
    - show_changes: False

dashboard_saved_objects_changes:
  file.absent:
    - names:
      - /opt/tc/state/kibana_saved_objects.txt
    - onchanges:
      - file: dashboard_saved_objects_template

tc-kibana-dashboard-load:
  cmd.run:
    - name: /usr/sbin/tc-kibana-config-load -i /opt/tc/conf/kibana/saved_objects.ndjson.template
    - cwd: /opt/so
    - require:
      - sls: kibana
      - file: dashboard_saved_objects_template
{%- if HIGHLANDER %}
dashboard_saved_objects_template_hl:
  file.managed:
    - name: /opt/tc/conf/kibana/hl.ndjson.template
    - source: salt://kibana/files/hl.ndjson
    - user: 932
    - group: 939
    - show_changes: False

dashboard_saved_objects_hl_changes:
  file.absent:
    - names:
      - /opt/tc/state/kibana_hl.txt
    - onchanges:
      - file: dashboard_saved_objects_template_hl

tc-kibana-dashboard-load_hl:
  cmd.run:
    - name: /usr/sbin/tc-kibana-config-load -i /opt/tc/conf/kibana/hl.ndjson.template
    - cwd: /opt/so
    - require:
      - sls: kibana
      - file: dashboard_saved_objects_template_hl
{%- endif %}
