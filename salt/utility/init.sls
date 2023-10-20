{% from 'allowed_states.map.jinja' import allowed_states %}

{% if sls in allowed_states %}
  {% from 'elasticsearch/auth.map.jinja' import ELASTICAUTH with context %}

# This state is for checking things
  {% if grains['role'] in ['tc-manager', 'tc-managersearch', 'tc-standalone'] %}
# Make sure Cross Cluster is good. Will need some logic once we have hot/warm
crossclusterson:
  cmd.script:
    - shell: /bin/bash
    - cwd: /opt/so
    - source: salt://utility/bin/crossthestreams
    - template: jinja
    - defaults:
        ELASTICCURL: {{ ELASTICAUTH.elasticcurl }}

  {% endif %}
  {% if grains['role'] in ['tc-eval', 'tc-import'] %}
fixsearch:
  cmd.script:
    - shell: /bin/bash
    - cwd: /opt/so
    - source: salt://utility/bin/eval
    - template: jinja
    - defaults:
        ELASTICCURL: {{ ELASTICAUTH.elasticcurl }}
  {% endif %}

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
