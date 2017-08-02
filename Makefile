######################################################################
# Create AWS stacks and tasks
######################################################################

# The default target -- other makefiles will add dependencies
all::

CLUSTER=$(PREFIX)-cluster

# Local variable overrides
-include local.mk

# Some standard make targets
include makefiles/standard.mk

# Use semantic versioning template
include makefiles/semver.mk

# and GIT release tools
include makefiles/git-release.mk

# a number of projects that track external state, including docker, aws stuff, ...
include makefiles/external-state.mk

# AWS docker magic
include makefiles/docker.mk
#include makefiles/aws-ecr.mk
include makefiles/aws-cloudformation.mk
include makefiles/aws-ecs.mk

######################################################################
#What we're trying to build here
######################################################################

ENVSUBST=envsubst

all:: $(SERVICESTATE)/webserver.service

export REGISTRY_BASE IMAGE_PREFIX TASK_PREFIX
%: %.template
	$(ENVSUBST) < $? > $@

# Not sure why the above rule doesn't work
%.taskdef: %.taskdef.template; 	$(ENVSUBST) < $? > $@
%.service: %.service.template; 	$(ENVSUBST) < $? > $@

######################################################################
# Cluster dependencies
######################################################################

$(CFSTATE)/$(PREFIX)-ecs-cluster.cf: $(CFSTATE)/$(PREFIX)-ecs-storage.cf


######################################################################
# Bootstrap ourselves by looking up VPC/Subnets/Etc
######################################################################

# The following magic creates an 'ecs-cluster.params' file if it does
# not already exist.  If it does exists, nothing is done even if it's
# not, theorietically, correct.

ifeq ($(wildcard ecs-cluster.params),ecs-cluster.params)
ecs-cluster.params:
else

ecs-cluster.params: $(STATE)/$(PROFILE)/subnets.txt $(STATE)/$(PROFILE)/keys.txt
	@echo ######################################################################
	@echo Determining default cluster parameters.  Feel free to edit ecs-cluster.params to change
	@echo ######################################################################
	@echo "VpcId=$$(cat $(STATE)/$(PROFILE)/vpcs.txt)" > $@
	@sed -n -e '1s/.*/SubnetA=&/p;2s/.*/SubnetB=&/p;3s/.*/SubnetC=&/p' < $(STATE)/$(PROFILE)/subnets.txt >> $@
	@sed -n -e '1s/.*/KeyName=&/p' < $(STATE)/$(PROFILE)/keys.txt >> $@


$(STATE)/$(PROFILE)/subnets.txt: $(STATE)/$(PROFILE)/vpcs.txt
	@echo -n "Finding Subnets..."
	@aws --profile $(PROFILE) --output text ec2 describe-subnets --filters Name=vpc-id,Values=$(file <$?) --query "Subnets[*].[SubnetId]" > $@
	@if [ $$(wc -l < $@) -lt 3 ] ; then echo "Must have at least 3 subnets in $$(cat $<)"; exit 1; else echo $$(cat $@ | tr -d "\r");  fi

$(STATE)/$(PROFILE)/vpcs.txt:
	@echo -n Finding VPC...
	@mkdir -p $(dir $@)
	@aws --profile $(PROFILE) --output text ec2 describe-vpcs --query "Vpcs[*].VpcId" > $@
	@if [ $$(wc -w < $@) -ne 1 ] ; then echo "Multiple VPCs found.  Cannot determine VPC for stack automatically"; echo "Must find one and only one VPC"; exit 1; else cat $@ ;fi

$(STATE)/$(PROFILE)/keys.txt:
	@echo -n Finding Keys...
	@aws --profile $(PROFILE) --output text ec2 describe-key-pairs --query "KeyPairs[*].[KeyName]" > $@
	@if [ $$(wc -l < $@) -ne 1 ] ; then echo "Found no key pairs.  No SSH possible"; exit 1; fi
endif

ifneq ($(wildcard ecs-storage.params),ecs-storage.params)
ecs-storage.params: ecs-cluster.params
	echo "Extracting parameters from $? for $@"
	@egrep "(VpcId|Subnet[ABC])=" $? > $@
endif

