include:
  - salt.minion-state-apply-test

state-apply-test:
  schedule.present:
    - name: salt-minion-state-apply-test
    - function: state.sls
    - job_args:
      - salt.minion-state-apply-test
    - minutes: 5
    - splay:
       start: 0
       end: 180

/usr/sbin/tc-salt-minion-check -q:
  cron.present:
    - identifier: tc-salt-minion-check
    - user: root
    - minute: '*/5'
