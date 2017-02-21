# Export all make variables as environment variables

TASK_PREFIX?=$(PREFIX)-

ECS=aws --profile $(PROFILE) ecs
ECSTEXT=aws --profile $(PROFILE) --output text ecs

# Directory to track deployed state
SERVICESTATE=$(STATE)/$(PROFILE)/$(CLUSTER)
TASKSTATE=$(STATE)/$(PROFILE)

# Calculate the targets we need to update -- i.e. calculate the names of
# all *targets* by examining the sources
TASKDEFS=$(wildcard *.taskdef)
SERVICES=$(wildcard *.service)

# How to deploy a task
$(TASKSTATE)/$(TASK_PREFIX)%.taskdef: %.taskdef 
	$(ECS) register-task-definition --family "$(NAME)" --cli-input-json file://$< --query "taskDefinition.[family,revision]"
	@touch $@


define drain-service
	   $(ECS) update-service --service $(NAME) --desired-count 0 --cluster $(CLUSTER)  --query "service.deployments[0].{desired:desiredCount,running:runningCount}"; \
	   while [ $$($(ECS) describe-services --cluster $(CLUSTER) --services $(NAME) --query "services[0].deployments[0].runningCount" | tr -d "\r") -ne 0 ] ; do echo "Waiting for service to stop"; $(ECS) describe-services --cluster $(CLUSTER) --services $(NAME) --query "services[0].deployments[0].{desired:desiredCount,running:runningCount}"; sleep 5s; done;
endef

# How to deploy a service
$(SERVICESTATE)/%.service: NAME=$(notdir $(basename $@))
$(SERVICESTATE)/%.service: %.service $(TASKSTATE)/$(TASK_PREFIX)%.taskdef
	@mkdir -p $(dir $@)
	@if [ -f $@ ] ; then \
	  echo "Updating service $(NAME)" ;\
	  $(ECS) update-service --service $(NAME) --cluster $(CLUSTER) --cli-input-json file://$< --query "service.[serviceArn,taskDefinition]" ;\
	  else \
	  echo "Creating service $(NAME)" ;\
	  $(ECS) create-service --cluster $(CLUSTER) --service-name "$(NAME)" --cli-input-json file://$< --query "service.[serviceArn,taskDefinition]" ;\
	fi
	@touch $@


templates: service.template taskdef.template

service.template:
	$(ECS) create-service --generate-cli-skeleton > $@

taskdef.template:
	$(ECS) register-task-definition --generate-cli-skeleton > $@

cleanup:: $(foreach v,$(shell echo *.taskdef),cleanup/$v)

cleanup/%.taskdef:
	   $(ECSTEXT) list-task-definitions --family-prefix $(notdir $*) | awk '{print $$2}' | head -n -3 | xargs -r -n 1 $(ECSTEXT) deregister-task-definition --query "['remove',taskDefinition.[family,':',revision]]" --task-definition; 

drain/%.service:
	-test -f $(SERVICESTATE)/$(notdir $@) && $(ECS) update-service --service $(notdir $*) --desired-count 0 --cluster $(CLUSTER) --query "service.[desiredCount]"

remove/%.service: drain/%.service
	-test -f $(SERVICESTATE)/$(notdir $@) && $(ECS) delete-service --service $(notdir $*) --cluster $(CLUSTER) --query "service.serviceArn" && sleep 20s
	rm -f $(SERVICESTATE)/$(notdir $@) $(SERVICESTATE)/$(notdir $*).taskservice

info::
	@echo TASKDEFS=$(TASKDEFS)
	@echo TASKSERVICES=$(TASKSERVICES)
	@echo SERVICES=$(SERVICES)


