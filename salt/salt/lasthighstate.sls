lasthighstate:
  file.touch:
    - name: /opt/tc/log/salt/lasthighstate
    - order: last