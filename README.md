# Docker image for running Tailscale on AWS Lambda

## Overview

Connects a Lambda function to your tailnet as an ephemeral node using userspace
networking. Exposes a SOCKS5 proxy endpoint for outbound connections to machines
on the tailnet.

## Configuration - environment variables

````
TAILSCALE_NODE_PREFIX=""            # prefix for the tailscale node name, will have a
                                    # random suffix appended to it
TAILSCALE_AUTHKEY=""                # authkey to use for connecting to the tailnet
TAILSCALE_USE_IPV6=""               # use IPV6 networking
TAILSCALE_SOCKS5_PROXY_PORT=1055    # port for the SOCKS5 proxy endpoint
````

## Usage

1. Example dockerfile:

````
FROM m4rkw/aws-lambda-python312-tailscale:latest

COPY requirements.txt /tmp

RUN pip install -r /tmp/requirements.txt

RUN rm -rf /var/task/python/__pycache__ /tmp/requirements.txt

ADD *.py ${LAMBDA_TASK_ROOT}/
ADD config.yaml ${LAMBDA_TASK_ROOT}/

CMD [ "collector.lambda_handler" ]
````

2. Generate an ephemeral reusable authkey for your tailnet through the admin
console. If the tailnet is locked you'll need to sign it:

````
$ tailscale lock sign <authkey>
````

3. Push the image to ECR

4. Deploy the Lambda function

````
resource "aws_lambda_function" "myfunction" {
  function_name                     = "myfunction"
  role                              = aws_iam_role.myfunction.arn
  timeout                           = 30
  reserved_concurrent_executions    = "1"
  image_uri                         = "<ecr image uri>"
  package_type                      = "Image"
  memory_size                       = 128
  architectures                     = ["x86_64"]

  environment {
    variables = {
      TAILSCALE_AUTHKEY             = "<AUTHKEY>"
      TAILSCALE_NODE_PREFIX         = "myfunction"
    }
  }
}
````

## Additional bootstrap script

If you add /var/task/bootstrap to your image it will be run before the Lambda
function.

## Forcing connections over the proxy

If your application doesn't support using a SOCKS5 proxy you can use socat which
is baked into the image to create a tcp proxy that forwards connections over the
proxy.

Example to forward connections on tcp/3307 to mysql.mydomain.com on tcp/3306:

create /var/task/bootstrap with:

````
#!/bin/sh
socat TCP-LISTEN:3307,reuseaddr,fork SOCKS5:127.0.0.1:mysql.mydomain.com:3306,socksport=1055 &
````
