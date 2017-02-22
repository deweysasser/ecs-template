# ecs-efs:  An ECS cluster with EFS persistence

This project contains all necessary files to automatically set up an
ECS cluster where each node mounts an efs file system on /cluster and
all nodes are running a proxy forwardward that can both forward web
requests and update route53 (therefore eliminating the need for an ELB
for each service).

## Installation


### Prerequisites

* Clone this project
* Ensure you have an appropriate profile in your `~/.aws/configuration`.
  This project uses "sandbox" by default
* add a line with `PROFILE=<your profile>` to `local.mk`
* if your AWS account has more than one VPC, create an
  `ecs-cluster.params` file that looks like below.  If you only have 1
  VPC with at least 3 subnets in it, the `ecs-cluster.params` file will be
  automatically created.

### Parameters File

     VpcId=vpc-12345
     SubnetA=subnet-12345
     SubnetB=subnet-23456
     SubnetC=subnet-34567
     KeyName=My SSH Key


### Building a cluster

* Run `make` twice (with a long delay in between). See [Why wait between make calls below](Why-wait-between-make-calls?) below.

Launching a cluster requires running `make` twice. The first time will launch a cloudformation stack defined by `ecs-cluster.cf`. The second run will load all `.taskdef` files in the directory you are running into your environment. After initial creation you will have a cluster running your defined services. In addition you will have several task defintions.

If you do this with no modifications you'll have a cluster with 2 services: a jenkins (singleton container) and a web server (2 containers, `nginx` and `name-based-proxy`).  

## Auto created services

[Taskdef](#.taskdef-files) files containing `"AUTOCREATE.SERVICE": ""` in their `ContainerDefinition` will automatically have n ECS service attached to it. If you wish to run multiple tasks in a given service you would write a `.service` files to define those needs.


## EFS cluster data persistence

Containers launched with the ecs-template have access to a shared `EFS` volume. You can mount folders to this volume in the `.taskdef` by including the following:

```
"volumes" : [
      {
         "name" : "home",
         "host" : {
            "sourcePath" : "/cluster/<path-name>"
         }
      }
   ]
```


### .taskdef tiles

For AWS documentation go [here](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definitions.html). There is a simplified verstion of the `.taskdef` file below. In addition you can define multiple containers to run and execute arbitrary actions. For instance adding the following before the main image configuration prepares the file system for `jenkins`:

    {
      "containerDefinitions" : [
        {
          "name": "permissions",
          "image": "busybox",
          "memoryReservation" : 16,
          "command": [
                  "sh",
                  "-c",
                  "chown -R 1000:1000 /var/jenkins_home"
          ],
          "mountPoints" : [
              {
                 "sourceVolume" : "home",
                 "containerPath" : "/var/jenkins_home",
                 "readOnly" : false
              }
         ],
        "essential": false
        },
        {
          // More containers
        }
      ]
    }

#### Example `.taskdef`

A `.taskdef` file defines the task to be launched in ECS. It requires a name, image and `memoryReservation`.

    {
      "containerDefinitions" : [
        {
           "name" : "<container-name>",
           "memoryReservation" : 256,
           "image" : "<repo/image>",
           "essential" : true,

           // there are for the name-based-routing
           "dockerLabels" : {
              "proxy.host" : "cost-dashboard-ecs.dgs.io",
              "proxy.ports" : "80:5001",
            "AUTOCREATE.SERVICE": ""
        },
        "portMappings" : [
          {
            "protocol" : "tcp",
            "containerPort" : 50000,
            "hostPort" : 50000
          }
       ],
        "environment" : [
          {
            "value" : "-Duser.timezone=America/New_York",
            "name" : "JAVA_OPTS"
          }
          ]
        }
      ]
    }


#### Why wait between make calls?

Unfortunately, due to the asynchronous nature of cloudformation and
the percularities of aws cli updates (e.g. missing
'stack-create-complete' commands), it is not straigt-forward to wait
until the stack is fully created.  Thus, the first time you run
'make', the stack creation will start but service deployment will fail
(because the cluster has not yet been created).

Wait for the stack creation to complete, then re-run make.

(Actually, you only have to wait until the cluster is created, not for
the full stack creation to work.  Once the cluster is created it will
accept the service definition and will run the service when it's
able.)

### Destroying the cluster

`make destroy CONFIRM=true` will take down the cloudformation stack
and destroy all associated resources.

Caveat: It will not currently destroy the cluster if there are any
services defined (see Issue #1).


### Name Based Proxy

You can run multiple web services with different DNS names through one
(or several) nodes.  This allows you to have a number of services in
different containers without using ELBs (and thus paying the costs of
an ELB per service).

Each node in the cluster runs a [name based proxy
server](https://github.com/deweysasser/docker-name-proxy-server),
which proxies traffic by accessed hostname.  Add a docker label
`proxy.host` to your container and traffic to that hostname will be
proxied to your container automatically.  If you have an appropriate
Route53 zone, entries will be automatically maintained as containers
are added.

### Private Docker Repositories

The host management task (defined in `ecs-cluster.cf`) runs a `docker login` proxy.  Create a file with appropriate login credentials for each private repository that you want the host to access in `/cluster/docker-login`. `docker login` will be automatically run with each line of the file.

An example file might be:

    -u quay_user -p password quay.io
    -u docker_user -p password

See [docker-login](https://hub.docker.com/r/deweysasser/docker-login/)
for details.

### Task and Services

Type 'make templates' to get templates for task and services.  These
are *exactly* the Amazon ECS templates for the repsective types.

As a speical case, to facilitate running singleton task services, if
the taskdef has "AUTOCREATE.SERVICE" anywhere in the body of the task
definition, a service will be created to run that task without the
need for a separate .service file.
