# Sync some Utilities
soup_scripts:
  file.recurse:
    - name: /usr/sbin
    - user: root
    - group: root
    - file_mode: 755
    - source: salt://common/tools/sbin
    - include_pat:
        - tc-common
        - tc-image-common

soup_manager_scripts:
  file.recurse:
    - name: /usr/sbin
    - user: root
    - group: root
    - file_mode: 755
    - source: salt://manager/tools/sbin
    - include_pat:
        - tc-firewall
        - tc-repo-sync
        - soup
