# Copyright 2014-2023 Threat Code Solutions, LLC

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
{% from 'allowed_states.map.jinja' import allowed_states %}
{% if sls in allowed_states and grains.role not in ['tc-manager', 'tc-managersearch'] %}

{% from "suricata/map.jinja" import SURICATAOPTIONS with context %}

{% set interface = salt['pillar.get']('sensor:interface', 'bond0') %}
{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% set BPF_NIDS = salt['pillar.get']('nids:bpf') %}
{% set BPF_STATUS = 0  %}

{# import_yaml 'suricata/files/defaults2.yaml' as suricata #}
{% from 'suricata/suricata_config.map.jinja' import suricata_defaults as suricata_config with context %}
{% from "suricata/map.jinja" import START with context %}

# Suricata

# Add Suricata Group
suricatagroup:
  group.present:
    - name: suricata
    - gid: 940

# Add Suricata user
suricata:
  user.present:
    - uid: 940
    - gid: 940
    - home: /nsm/suricata
    - createhome: False

socoregroupwithsuricata:
  group.present:
    - name: socore
    - gid: 939
    - addusers:
      - suricata

suridir:
  file.directory:
    - name: /opt/tc/conf/suricata
    - user: 940
    - group: 940

suriruledir:
  file.directory:
    - name: /opt/tc/conf/suricata/rules
    - user: 940
    - group: 940
    - makedirs: True

surilogdir:
  file.directory:
    - name: /opt/tc/log/suricata
    - user: 940
    - group: 939

suridatadir:
  file.directory:
    - name: /nsm/suricata/extracted
    - user: 940
    - group: 939
    - mode: 770
    - makedirs: True

surirulesync:
  file.recurse:
    - name: /opt/tc/conf/suricata/rules/
    - source: salt://suricata/rules/
    - user: 940
    - group: 940
    - show_changes: False

surilogscript:
  file.managed:
    - name: /usr/local/bin/surilogcompress
    - source: salt://suricata/cron/surilogcompress
    - mode: 755

/usr/local/bin/surilogcompress:
  cron.present:
    - user: suricata
    - minute: '17'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

suriconfig:
  file.managed:
    - name: /opt/tc/conf/suricata/suricata.yaml
    - source: salt://suricata/files/suricata.yaml.jinja
    - context:
        suricata_config: {{ suricata_config.suricata.config }}
    - user: 940
    - group: 940
    - template: jinja

surithresholding:
  file.managed:
    - name: /opt/tc/conf/suricata/threshold.conf
    - source: salt://suricata/files/threshold.conf.jinja
    - user: 940
    - group: 940
    - template: jinja

classification_config:
  file.managed:
    - name: /opt/tc/conf/suricata/classification.config
    - source: salt://suricata/files/classification.config.jinja
    - user: 940
    - group: 940
    - template: jinja

# BPF compilation and configuration
{% if BPF_NIDS %}
   {% set BPF_CALC = salt['cmd.script']('/usr/sbin/tc-bpf-compile', interface + ' ' + BPF_NIDS|join(" "),cwd='/root') %}
   {% if BPF_CALC['stderr'] == "" %}
      {% set BPF_STATUS = 1  %}
   {% else  %}
suribpfcompilationfailure:
  test.configurable_test_state:
   - changes: False
   - result: False
   - comment: "BPF Syntax Error - Discarding Specified BPF"
   {% endif %}
{% endif %}

suribpf:
  file.managed:
    - name: /opt/tc/conf/suricata/bpf
    - user: 940
    - group: 940
   {% if BPF_STATUS %}
    - contents_pillar: nids:bpf
   {% else %}
    - contents:
      - ""
   {% endif %}

tc-suricata:
  docker_container.{{ SURICATAOPTIONS.status }}:
  {% if SURICATAOPTIONS.status == 'running' %}
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-suricata:{{ VERSION }}
    - start: {{ SURICATAOPTIONS.start }}
    - privileged: True
    - environment:
      - INTERFACE={{ interface }}
    - binds:
      - /opt/tc/conf/suricata/suricata.yaml:/etc/suricata/suricata.yaml:ro
      - /opt/tc/conf/suricata/threshold.conf:/etc/suricata/threshold.conf:ro
      - /opt/tc/conf/suricata/classification.config:/etc/suricata/classification.config:ro
      - /opt/tc/conf/suricata/rules:/etc/suricata/rules:ro
      - /opt/tc/log/suricata/:/var/log/suricata/:rw
      - /nsm/suricata/:/nsm/:rw
      - /nsm/suricata/extracted:/var/log/suricata//filestore:rw
      - /opt/tc/conf/suricata/bpf:/etc/suricata/bpf:ro
    - network_mode: host
    - watch:
      - file: suriconfig
      - file: surithresholding
      - file: /opt/tc/conf/suricata/rules/
      - file: /opt/tc/conf/suricata/bpf
      - file: classification_config
    - require:
      - file: suriconfig
      - file: surithresholding
      - file: suribpf
      - file: classification_config

  {% else %} {# if Suricata isn't enabled, then stop and remove the container #}
    - force: True
  {% endif %}

append_tc-suricata_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-suricata
    - unless: grep -q tc-suricata /opt/tc/conf/tc-status/tc-status.conf

  {% if not SURICATAOPTIONS.start %}
tc-suricata_tc-status.disabled:
  file.comment:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - regex: ^tc-suricata$
  {% else %}
delete_tc-suricata_tc-status.disabled:
  file.uncomment:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - regex: ^tc-suricata$
  {% endif %}

/usr/local/bin/surirotate:
  cron.absent:
    - user: root
    - minute: '11'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

tc-suricata-eve-clean:
  file.managed:
    - name: /usr/sbin/tc-suricata-eve-clean
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - source: salt://suricata/cron/tc-suricata-eve-clean

# Add eve clean cron
clean_suricata_eve_files:
  cron.present:
    - name: /usr/sbin/tc-suricata-eve-clean > /dev/null 2>&1
    - user: root
    - minute: '*/5'
    - hour: '*'
    - daymonth: '*'
    - month: '*'
    - dayweek: '*'

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
