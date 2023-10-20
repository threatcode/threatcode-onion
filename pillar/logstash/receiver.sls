logstash:
  pipelines:
    receiver:
      config:
        - tc/0009_input_beats.conf      
        - tc/0010_input_hhbeats.conf
        - tc/0011_input_endgame.conf
        - tc/9999_output_redis.conf.jinja
        