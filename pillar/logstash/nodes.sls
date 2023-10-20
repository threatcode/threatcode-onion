{% set node_types = {} %}
{% set cached_grains = salt.saltutil.runner('cache.grains', tgt='*') %}
{% for minionid, ip in salt.saltutil.runner(
    'mine.get',
    tgt='G@role:tc-manager or G@role:tc-managersearch or G@role:tc-standalone or G@role:tc-node or G@role:tc-heavynode or G@role:tc-receiver or G@role:tc-helix',
    fun='network.ip_addrs',
    tgt_type='compound') | dictsort()
%}

{%   set hostname = cached_grains[minionid]['host'] %}
{%   set node_type = minionid.split('_')[1] %}
{%   if node_type not in node_types.keys() %}
{%     do node_types.update({node_type: {hostname: ip[0]}}) %}
{%   else %}
{%     if hostname not in node_types[node_type] %}
{%       do node_types[node_type].update({hostname: ip[0]}) %}
{%     else %}
{%       do node_types[node_type][hostname].update(ip[0]) %}
{%     endif %}
{%   endif %}
{% endfor %}

logstash:
  nodes:
{% for node_type, values in node_types.items() %}
    {{node_type}}:
{%   for hostname, ip in values.items() %}
      {{hostname}}:
        ip: {{ip}}
{%   endfor %}
{% endfor %}
