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
{% if sls in allowed_states %}

{% from "pcap/map.jinja" import STENOOPTIONS with context %}

{% set VERSION = salt['pillar.get']('global:soversion', 'HH1.2.2') %}
{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}
{% set MANAGER = salt['grains.get']('master') %}
{% set INTERFACE = salt['pillar.get']('sensor:interface', 'bond0') %}
{% set BPF_STENO = salt['pillar.get']('steno:bpf', None) %}
{% set BPF_COMPILED = "" %}

# PCAP Section

stenographergroup:
  group.present:
    - name: stenographer
    - gid: 941

stenographer:
  user.present:
    - uid: 941
    - gid: 941
    - home: /opt/tc/conf/steno

stenoconfdir:
  file.directory:
    - name: /opt/tc/conf/steno
    - user: 941
    - group: 939
    - makedirs: True

{% if BPF_STENO %}
   {% set BPF_CALC = salt['cmd.script']('/usr/sbin/tc-bpf-compile', INTERFACE + ' ' + BPF_STENO|join(" "),cwd='/root') %}
   {% if BPF_CALC['stderr'] == "" %}
      {% set BPF_COMPILED =  ",\\\"--filter=" + BPF_CALC['stdout'] + "\\\""  %}
   {% else  %}

bpfcompilationfailure:
  test.configurable_test_state:
   - changes: False
   - result: False
   - comment: "BPF Compilation Failed - Discarding Specified BPF"
   {% endif %}
{% endif %}

stenoconf:
  file.managed:
    - name: /opt/tc/conf/steno/config
    - source: salt://pcap/files/config
    - user: stenographer
    - group: stenographer
    - mode: 644
    - template: jinja
    - defaults:
        BPF_COMPILED: "{{ BPF_COMPILED }}"

stenoca:
  file.directory:
    - name: /opt/tc/conf/steno/certs
    - user: 941
    - group: 939

pcapdir:
  file.directory:
    - name: /nsm/pcap
    - user: 941
    - group: 941
    - makedirs: True

pcaptmpdir:
  file.directory:
    - name: /nsm/pcaptmp
    - user: 941
    - group: 941
    - makedirs: True

pcapoutdir:
  file.directory:
    - name: /nsm/pcapout
    - user: 939
    - group: 939
    - makedirs: True

pcapindexdir:
  file.directory:
    - name: /nsm/pcapindex
    - user: 941
    - group: 941
    - makedirs: True

stenolog:
  file.directory:
    - name: /opt/tc/log/stenographer
    - user: 941
    - group: 941
    - makedirs: True

tc-steno:
  docker_container.{{ STENOOPTIONS.status }}:
  {% if STENOOPTIONS.status == 'running' %}
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-steno:{{ VERSION }}
    - start: {{ STENOOPTIONS.start }}
    - network_mode: host
    - privileged: True
    - binds:
      - /opt/tc/conf/steno/certs:/etc/stenographer/certs:rw
      - /opt/tc/conf/steno/config:/etc/stenographer/config:rw
      - /nsm/pcap:/nsm/pcap:rw
      - /nsm/pcapindex:/nsm/pcapindex:rw
      - /nsm/pcaptmp:/tmp:rw
      - /opt/tc/log/stenographer:/var/log/stenographer:rw
    - watch:
      - file: stenoconf
    - require:
      - file: stenoconf
  {% else %} {# if stenographer isn't enabled, then stop and remove the container #}
    - force: True
  {% endif %}

append_tc-steno_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-steno
    - unless: grep -q tc-steno /opt/tc/conf/tc-status/tc-status.conf

  {% if not STENOOPTIONS.start %}
tc-steno_tc-status.disabled:
  file.comment:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - regex: ^tc-steno$
  {% else %}
delete_tc-steno_tc-status.disabled:
  file.uncomment:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - regex: ^tc-steno$
  {% endif %}

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
