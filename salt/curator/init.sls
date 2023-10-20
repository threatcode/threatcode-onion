{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% set REMOVECURATORCRON = False %}
{% set TRUECLUSTER = salt['pillar.get']('elasticsearch:true_cluster', False) %}
{% set HOTWARM = salt['pillar.get']('elasticsearch:hot_warm_enabled', False) %}

{% if grains['role'] in ['tc-eval', 'tc-node', 'tc-managersearch', 'tc-heavynode', 'tc-standalone', 'tc-manager'] %}
  {% from 'elasticsearch/auth.map.jinja' import ELASTICAUTH with context %}
  {% from "curator/map.jinja" import CURATOROPTIONS with context %}
# Curator
# Create the group
curatorgroup:
  group.present:
    - name: curator
    - gid: 934

# Add user
curator:
  user.present:
    - uid: 934
    - gid: 934
    - home: /opt/tc/conf/curator
    - createhome: False

# Create the log directory
curactiondir:
  file.directory:
    - name: /opt/tc/conf/curator/action
    - user: 934
    - group: 939
    - makedirs: True

curlogdir:
  file.directory:
    - name: /opt/tc/log/curator
    - user: 934
    - group: 939

actionconfs:
  file.recurse:
    - name: /opt/tc/conf/curator/action
    - source: salt://curator/files/action
    - user: 934
    - group: 939
    - template: jinja

curconf:
  file.managed:
    - name: /opt/tc/conf/curator/curator.yml
    - source: salt://curator/files/curator.yml
    - user: 934
    - group: 939
    - mode: 660
    - template: jinja
    - show_changes: False

curcloseddel:
  file.managed:
    - name: /usr/sbin/tc-curator-closed-delete
    - source: salt://curator/files/bin/tc-curator-closed-delete
    - user: 934
    - group: 939
    - mode: 755

curcloseddeldel:
  file.managed:
    - name: /usr/sbin/tc-curator-closed-delete-delete
    - source: salt://curator/files/bin/tc-curator-closed-delete-delete
    - user: 934
    - group: 939
    - mode: 755
    - template: jinja
    - defaults:
        ELASTICCURL: {{ ELASTICAUTH.elasticcurl }}

curclose:
  file.managed:
    - name: /usr/sbin/tc-curator-close
    - source: salt://curator/files/bin/tc-curator-close
    - user: 934
    - group: 939
    - mode: 755
    - template: jinja

curdel:
  file.managed:
    - name: /usr/sbin/tc-curator-delete
    - source: salt://curator/files/bin/tc-curator-delete
    - user: 934
    - group: 939
    - mode: 755

curclusterclose: 
  file.managed:
    - name: /usr/sbin/tc-curator-cluster-close
    - source: salt://curator/files/bin/tc-curator-cluster-close
    - user: 934
    - group: 939
    - mode: 755
    - template: jinja

curclusterdelete: 
  file.managed:
    - name: /usr/sbin/tc-curator-cluster-delete
    - source: salt://curator/files/bin/tc-curator-cluster-delete
    - user: 934
    - group: 939
    - mode: 755
    - template: jinja

curclustercwarm: 
  file.managed:
    - name: /usr/sbin/tc-curator-cluster-warm
    - source: salt://curator/files/bin/tc-curator-cluster-warm
    - user: 934
    - group: 939
    - mode: 755
    - template: jinja

tc-curator:
  docker_container.{{ CURATOROPTIONS.status }}:
  {% if CURATOROPTIONS.status == 'running' %}
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-curator:{{ VERSION }}
    - start: {{ CURATOROPTIONS.start }}
    - hostname: curator
    - name: tc-curator
    - user: curator
    - interactive: True
    - tty: True
    - binds:
      - /opt/tc/conf/curator/curator.yml:/etc/curator/config/curator.yml:ro
      - /opt/tc/conf/curator/action/:/etc/curator/action:ro
      - /opt/tc/log/curator:/var/log/curator:rw
    - require:
      - file: actionconfs
      - file: curconf
      - file: curlogdir
    - watch:
      - file: curconf
  {% else %}
    - force: True
  {% endif %}

  {% if CURATOROPTIONS.manage_tcstatus %}
append_tc-curator_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-curator
    - unless: grep -q tc-curator /opt/tc/conf/tc-status/tc-status.conf

    {% if not CURATOROPTIONS.start %}
tc-curator_tc-status.disabled:
  file.comment:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - regex: ^tc-curator$

      # need to remove cronjobs here since curator is disabled
      {% set REMOVECURATORCRON = True %}    
    {% else %}
delete_tc-curator_tc-status.disabled:
  file.uncomment:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - regex: ^tc-curator$

    {% endif %}

  {% else %}
delete_tc-curator_tc-status:
  file.line:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - match: ^tc-curator$
    - mode: delete

    # need to remove cronjobs here since curator is disabled
    {% set REMOVECURATORCRON = True %}

  {% endif %}

  {% if REMOVECURATORCRON %}
tc-curatorcloseddeletecron:
  cron.absent:
    - name: /usr/sbin/tc-curator-closed-delete > /opt/tc/log/curator/cron-closed-delete.log 2>&1
    - user: root

tc-curatorclosecron:
  cron.absent:
    - name: /usr/sbin/tc-curator-close > /opt/tc/log/curator/cron-close.log 2>&1
    - user: root

tc-curatordeletecron:
  cron.absent:
    - name: /usr/sbin/tc-curator-delete > /opt/tc/log/curator/cron-delete.log 2>&1
    - user: root

  {% else %}

    {% if TRUECLUSTER is sameas true %}  
tc-curatorclusterclose:
  cron.present:
    - name: /usr/sbin/tc-curator-cluster-close > /opt/tc/log/curator/cron-close.log 2>&1
    - user: root
    - minute: '5'
    - hour: '1'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

tc-curatorclusterdelete:
  cron.present:
    - name: /usr/sbin/tc-curator-cluster-delete > /opt/tc/log/curator/cron-delete.log 2>&1
    - user: root
    - minute: '5'
    - hour: '1'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'
        {% if HOTWARM is sameas true %}
tc-curatorclusterwarm:
  cron.present:
    - name: /usr/sbin/tc-curator-cluster-warm > /opt/tc/log/curator/cron-warm.log 2>&1
    - user: root
    - minute: '5'
    - hour: '1'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'
        {% endif %}

    {% else %}
tc-curatorcloseddeletecron:
  cron.present:
    - name: /usr/sbin/tc-curator-closed-delete > /opt/tc/log/curator/cron-closed-delete.log 2>&1
    - user: root
    - minute: '*/5'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

tc-curatorclosecron:
  cron.present:
    - name: /usr/sbin/tc-curator-close > /opt/tc/log/curator/cron-close.log 2>&1
    - user: root
    - minute: '*/5'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

tc-curatordeletecron:
  cron.present:
    - name: /usr/sbin/tc-curator-delete > /opt/tc/log/curator/cron-delete.log 2>&1
    - user: root
    - minute: '*/5'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'
  
    {% endif %}
  {% endif %}
{% endif %}

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
