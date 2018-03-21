#!/bin/bash
terraform -v
terrafrom init $tf_resource
if [ "$purge_vm" = "true" ] ; then terraform destroy -force $tf_resource; fi
terraform apply $tf_resource
if [ "$keep_vm" != "true" ] ; then terraform destroy -force $tf_resource; fi
