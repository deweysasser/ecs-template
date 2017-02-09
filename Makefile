######################################################################
# Create AWS stacks and tasks
######################################################################

all:

# Use semantic versioning template
include semver.mk

# and GIT release tools
include release.mk

# Activiate AWS CloudFormation stack creation
include aws-cf.mk

