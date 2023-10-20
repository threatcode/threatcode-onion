logstash:
  pipelines:
    search:
      config:
        - tc/0900_input_redis.conf.jinja
        - tc/9000_output_zeek.conf.jinja
        - tc/9002_output_import.conf.jinja
        - tc/9034_output_syslog.conf.jinja
        - tc/9050_output_filebeatmodules.conf.jinja
        - tc/9100_output_osquery.conf.jinja  
        - tc/9400_output_suricata.conf.jinja
        - tc/9500_output_beats.conf.jinja
        - tc/9600_output_ossec.conf.jinja
        - tc/9700_output_strelka.conf.jinja
        - tc/9800_output_logscan.conf.jinja
        - tc/9801_output_rita.conf.jinja
        - tc/9802_output_kratos.conf.jinja
        - tc/9900_output_endgame.conf.jinja
