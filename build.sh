#!/bin/bash
TFBIN=./terraform
$TFBIN -v
$TFBIN init $tf_resource
if [ "$purge_vm" = "true" ] ; then $TFBIN destroy -force $tf_resource; fi
$TFBIN apply $tf_resource
if [ "$keep_vm" != "true" ] ; then $TFBIN destroy -force $tf_resource; fi
