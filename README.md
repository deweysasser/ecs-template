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

Persisting state across the cluster
-----------------------------------

In order for state to persist across services in the cluster, mount a
path from /cluster/... into your container.  Now, wherever in the
cluster your service is started, it will have access to all state.

Name Based Proxy
----------------

You can run multiple web services with different DNS names through one
(or several) nodes.  This allows you to have a number of services in
different containres without using ELBs (and thus paying the costs of
an ELB per service).

Each node in the cluster runs a [name based proxy
server](https://github.com/deweysasser/docker-name-proxy-server),
which proxies traffic by accessed hostname.  Add a docker label
"proxy.host" to your container and traffic to that hostname will be
proxied to your container automatically.  If you have an appropriate
Route53 zone, entries will be automatically maintained as containers
are added.

Task and Services
-----------------

Type 'make templates' to get templates for task and services.  These
are *exactly* the Amazon ECS templates for the repsective types.

As a speical case, to facilitate running singleton task services, if
the taskdef has "AUTOCREATE.SERVICE" anywhere in the body of the task
definition, a service will be created to run that task without the
need for a separate .service file.