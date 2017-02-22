ecs-efs:  An ECS cluster with EFS persistence
=============================================

This project contains all necessary files to automatically set up an
ECS cluster where each node mounts an efs file system on /cluster and
all nodes are running a proxy forwardward that can both forward web
requests and update route53 (therefore eliminating the need for an ELB
for each service).

INSTALL
-------

### Prerequisites

* Clone this project
* ensure you have an appropriate profile in your ~/.aws/configuration.
  This project uses "sandbox" by default
* add a line with "PROFILE=<your profile" to local.mk
* if your AWS account has more than one VPC, create an
  "ecs-cluster.params" file that looks like below.  If you only have 1
  VPC with at least 3 subnets in it, the ecs-cluster.params file will be
  automatically created.

### Parameters File

     VpcId=vpc-12345
     SubnetA=subnet-12345
     SubnetB=subnet-23456
     SubnetC=subnet-34567
     KeyName=My SSH Key


### Building the cluster


Run 'make' twice (with a long delay in between)

When done, you'll have a cluster with 2 services: a jenkins (singleton
container) and a web server (2 containers).  Both services put their
data in EFS.

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

Destroying the cluster
----------------------

'make destroy CONFIRM=true' will take down the cloudformation stack
and destroy all associated resources.

Caveat: It will not currently destroy the cluster if there are any
services defined (see Issue #1).

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

Private Docker Repositories
---------------------------

The host management task runs a "docker login" proxy.  Create a file
with appropriate login credentials for each private repository that
you want the host to access in /cluster/docker-login.  "docker login"
will be automtically run with each line of the file.

An example file might be:

    -u quay_user -p password quay.io
    -u docker_user -p password

See [docker-login](https://hub.docker.com/r/deweysasser/docker-login/)
for details.

Task and Services
-----------------

Type 'make templates' to get templates for task and services.  These
are *exactly* the Amazon ECS templates for the repsective types.

As a speical case, to facilitate running singleton task services, if
the taskdef has "AUTOCREATE.SERVICE" anywhere in the body of the task
definition, a service will be created to run that task without the
need for a separate .service file.