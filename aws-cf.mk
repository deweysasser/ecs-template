######################################################################
# Create AWS stacks and tasks
######################################################################

# the project we're working in
PROJECT=$(notdir $(CURDIR))

# A prefix applied to all resources so different users/contexts do not
# step on each other
PREFIX?=$(PROJECT)-$(USER)

# The AWS profile to use 
PROFILE?=default

# Directory in which we store runtime state
RUNNING?=.running

# AWS command
AWS=aws --profile $(PROFILE)

# Default targets
all: $(foreach s,$(wildcard *.stack),$(RUNNING)/$(PREFIX)-$(notdir $s))


# The standard set of parameters we supply to every cloudformation template
STANDARD_PARAMETERS=ParameterKey=Prefix,ParameterValue=$(PREFIX) ParameterKey=CreatedBy,ParameterValue=$(USER) 

# How to turn a .params files into a command line set of
# cloudformation parameters

define PARAMETERS
$(shell perl -n -e 'next if /^#/; next if /^$$/; if (/(.*?)(\s*=\s*)(.*?)$$/) { print "ParameterKey=$$1,ParameterValue=$$3 " }' $1)
endef

######################################################################
# How to build stacks
######################################################################

$(RUNNING)/$(PREFIX)-%.stack: $(RUNNING)

$(RUNNING)/$(PREFIX)-%.stack: %.stack %.params $(RUNNING)
	if [ -f $@ ] ; then \
	$(AWS) cloudformation  update-stack --capabilities CAPABILITY_IAM  --stack-name $(PREFIX)-$* --template-body file://$<  --parameters $(STANDARD_PARAMETERS) $(call PARAMETERS,$*.params); \
	else  \
	$(AWS) cloudformation  create-stack --capabilities CAPABILITY_IAM  --stack-name $(PREFIX)-$* --template-body file://$<  --parameters $(STANDARD_PARAMETERS) $(call PARAMETERS,$*.params); \
	fi
	touch $@

%.params:
	touch $@

######################################################################
# How to destroy stacks
######################################################################

delete/%.stack: $(RUNNING) 
	test -f $(RUNNING)/$(PREFIX)-$* && $(AWS) cloudformation delete-stack --stack-name $(PREFIX)-$(basename $*) || true
	rm $(RUNNING)/$(PREFIX)-$*

# Purge is a speical case -- it's a very dangerous operation, so only allow it if we explitictly confirm
ifeq ($(CONFIRM),yes)
purge: $(foreach s,$(wildcard *.stack),delete/$s.stack)
else
purge:
	@echo "WARNING:  'make purge' is dangerous."
	@echo "It will delete all stack resources *INCLUDING* buckets and file systems with data"
	@printf "\nPurge would delete the following stacks: $(foreach s,$(wildcard *.stack),\n   - $(PREFIX)-$(subst .stack,,$s))\n\n"
	@echo "You must run it with:"
	@echo "  make $(MAKEFLAGS) purge CONFIRM=yes"
endif

######################################################################
# Templates for various types
######################################################################

templates: templates/stack.template
templates/stack.template:
	mkdir -p $(dir $@)
	$(AWS) cloudformation create-stack --generate-cli-skeleton > $@

######################################################################
# Generate the state capture directory and pre-populate it
######################################################################

$(RUNNING):
	mkdir -p $@
	for stack in $$($(AWS) --output text cloudformation describe-stacks --query "Stacks[*].StackName" | tr -d '\r'); do echo Found stack $$stack; touch $@/$$stack.stack; done


# Print general info
info::
	@echo PROJECT = $(PROJECT)