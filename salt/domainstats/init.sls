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

{% set IMAGEREPO = salt['pillar.get']('global:imagerepo') %}

# Create the group
dstatsgroup:
  group.present:
    - name: domainstats
    - gid: 936

# Add user
domainstats:
  user.present:
    - uid: 936
    - gid: 936
    - home: /opt/tc/conf/domainstats
    - createhome: False

# Create the log directory
dstatslogdir:
  file.directory:
    - name: /opt/tc/log/domainstats
    - user: 936
    - group: 939
    - makedirs: True

tc-domainstatsimage:
 cmd.run:
   - name: docker pull {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-domainstats:{{ VERSION }}

tc-domainstats:
  docker_container.running:
    - image: {{ MANAGER }}:5000/{{ IMAGEREPO }}/tc-domainstats:{{ VERSION }}
    - hostname: domainstats
    - name: tc-domainstats
    - user: domainstats
    - binds:
      - /opt/tc/log/domainstats:/var/log/domain_stats
    - require:
      - file: dstatslogdir
      - cmd: tc-domainstatsimage

append_tc-domainstats_tc-status.conf:
  file.append:
    - name: /opt/tc/conf/tc-status/tc-status.conf
    - text: tc-domainstats

{% else %}

{{sls}}_state_not_allowed:
  test.fail_without_changes:
    - name: {{sls}}_state_not_allowed

{% endif %}
