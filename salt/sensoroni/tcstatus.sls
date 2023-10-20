# Copyright Security Onion Solutions LLC and/or licensed to Security Onion Solutions LLC under one
# or more contributor license agreements. Licensed under the Elastic License 2.0 as shown at 
# https://threatcode.net/license; you may not use this file except in compliance with the
# Elastic License 2.0.

append_so-sensoroni_so-status.conf:
  file.append:
    - name: /opt/tc/conf/so-status/so-status.conf
    - text: tc-sensoroni
    - unless: grep -q tc-sensoroni /opt/tc/conf/so-status/so-status.conf
