#!/bin/bash
aws elasticbeanstalk update-environment \
 --application-name ${appname} \
 --environment-id ${envid} \
 --version-label ${verlabel}
