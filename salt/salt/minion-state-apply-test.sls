minion-state-apply-test:
  file.touch:
    - name: /opt/tc/log/salt/state-apply-test
    - order: first