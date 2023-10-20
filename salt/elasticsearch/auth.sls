{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

  {% set DIGITS = "1234567890" %}
  {% set LOWERCASE = "qwertyuiopasdfghjklzxcvbnm" %}
  {% set UPPERCASE = "QWERTYUIOPASDFGHJKLZXCVBNM" %}
  {% set SYMBOLS = "~!@#^&*()-_=+[]|;:,.<>?" %}
  {% set CHARS = DIGITS~LOWERCASE~UPPERCASE~SYMBOLS %}
  {% set tc_elastic_user_pass = salt['pillar.get']('elasticsearch:auth:users:tc_elastic_user:pass', salt['random.get_str'](72, chars=CHARS)) %}
  {% set tc_kibana_user_pass = salt['pillar.get']('elasticsearch:auth:users:tc_kibana_user:pass', salt['random.get_str'](72, chars=CHARS)) %}
  {% set tc_logstash_user_pass = salt['pillar.get']('elasticsearch:auth:users:tc_logstash_user:pass', salt['random.get_str'](72, chars=CHARS)) %}
  {% set tc_beats_user_pass = salt['pillar.get']('elasticsearch:auth:users:tc_beats_user:pass', salt['random.get_str'](72, chars=CHARS)) %}
  {% set tc_monitor_user_pass = salt['pillar.get']('elasticsearch:auth:users:tc_monitor_user:pass', salt['random.get_str'](72, chars=CHARS)) %}
  {% set auth_enabled = salt['pillar.get']('elasticsearch:auth:enabled', False) %}

elastic_auth_pillar:
  file.managed:
    - name: /opt/tc/saltstack/local/pillar/elasticsearch/auth.sls
    - mode: 600
    - reload_pillar: True
    - contents: |
        elasticsearch:
          auth:
            enabled: {{ auth_enabled }}
            users:
              tc_elastic_user:
                user: tc_elastic
                pass: "{{ tc_elastic_user_pass }}"
              tc_kibana_user:
                user: tc_kibana
                pass: "{{ tc_kibana_user_pass }}"
              tc_logstash_user:
                user: tc_logstash
                pass: "{{ tc_logstash_user_pass }}"
              tc_beats_user:
                user: tc_beats
                pass: "{{ tc_beats_user_pass }}"
              tc_monitor_user:
                user: tc_monitor
                pass: "{{ tc_monitor_user_pass }}"
    - show_changes: False
{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
