# Sync some Utilities
tcup_scripts:
  file.recurse:
    - name: /usr/sbin
    - user: root
    - group: root
    - file_mode: 755
    - source: salt://common/tools/sbin
    - include_pat:
        - tc-common
        - tc-firewall
        - tc-image-common
        - tcup
