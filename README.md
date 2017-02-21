ecs-efs:  An ECS cluster with EFS persistence
=============================================

This project contains all necessary files to automatically set up an
ECS cluster where each node mounts an efs file system on /cluster and
all nodes are running a proxy forwardward that can both forward web
requests and update route53 (therefore eliminating the need for an ELB
for each service).

Quickstart
----------

Run 'make' twice (with a long delay in between)

Unfortunately, due to the asynchronous nature of cloudformation and
the peduclarities of aws cli updates (e.g. missing
'stack-create-complete' commands), it is not straigt-forward to wait
until the stack is fully created.  Thus, the first time you run
'make', the stack creation will start but service deployment will fail
(because the cluster has not yet been created).

Wait for the stack creation to complete, then re-run make.

(Actually, you only have to wait until the cluster is created, not for
the full stack creation to work.  Once the cluster is created it will
accept the service definition and will run the service when it's
able.)