# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://threatcode.github.io/license; you may not use this file except in compliance with the
# Elastic License 2.0.


idstoolsdir:
  file.directory:
    - name: /opt/tc/conf/idstools/etc
    - user: 939
    - group: 939
    - makedirs: True

idstoolsetcsync:
  file.recurse:
    - name: /opt/tc/conf/idstools/etc
    - source: salt://idstools/etc
    - user: 939
    - group: 939
    - template: jinja

rulesdir:
  file.directory:
    - name: /opt/tc/rules/nids
    - user: 939
    - group: 939
    - makedirs: True

# Don't show changes because all.rules can be large
synclocalnidsrules:
  file.recurse:
    - name: /opt/tc/rules/nids/
    - source: salt://idstools/rules/
    - user: 939
    - group: 939
    - show_changes: False
    - include_pat: 'E@.rules'
