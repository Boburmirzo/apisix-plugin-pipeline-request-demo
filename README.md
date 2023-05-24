# Chaining API requests with API Gateway Demo.

For this demo, we are going to leverage another prepared [demo project](https://github.com/Boburmirzo/apisix-plugin-pipeline-request-demo) on GitHub where you can find all [curl command examples](https://github.com/Boburmirzo/apisix-plugin-pipeline-request-demo/tree/main/curl-cmds) used in this tutorial, run APISIX and enable a [custom plugin](https://github.com/Boburmirzo/apisix-plugin-pipeline-request-demo/blob/main/custom-plugins/pipeline-request.lua) without additional configuration with a [Docker compose](https://github.com/Boburmirzo/apisix-plugin-pipeline-request-demo/blob/main/docker-compose.yml).yml file.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) is used to installing the containerized etcd and APISIX.
- [curl](https://curl.se/) is used to send requests to APISIX Admin API. You can also use easy tools such as [Postman](https://www.postman.com/) to interact with the API.

### Step 1: Install and run APISIX and etcd

You can easily install APISIX and etcd by running `docker compose up` from the project root folder after you fork/clone [the project](https://github.com/Boburmirzo/apisix-plugin-pipeline-request-demo). You may notice that there is a volume `./custom-plugins:/opt/apisix/plugins:ro` specified in `docker-compose.yml` file. This mounts the local directory**`./custom-plugins`** where our `pipeline-request.lua` file with the custom plugin implementation as a read-only volume in the docker container at the path **`/opt/apisix/plugins`**. This allows custom plugins to be added to APISIX in the runtime (This setup is only applicable if you run APISIX with docker).

### Step 2:  Create the first Route with the pipeline-request plugin

Once APISIX is running, we use cURL command that is used to send an HTTP PUT request to the APISIX Admin API `/routes` endpoint to create our first route that listens for URI path `/my-credit-cards`.

```bash
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/1' \
--header 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
--header 'Content-Type: application/json' \
--data-raw '{
   "uri":"/my-credit-cards",
   "plugins":{
      "pipeline-request":{
         "nodes":[
            {
               "url":"https://random-data-api.com/api/v2/credit_cards"
            },
            {
               "url":"http://127.0.0.1:9080/filter"
            }
         ]
      }
   }
}'
```

The important part of the configuration is the "plugins" section, which specifies that the "pipeline-request" plugin should be used for this API route. The plugin configuration contains a "nodes" array, which defines the sequence of API requests that should be executed in the pipeline. You can define one or multiple APIs there. In this case, the pipeline consists of two nodes: the first node sends a request to the [https://random-data-api.com/api/v2/credit_cards](https://random-data-api.com/api/v2/credit_cards)  ****API to retrieve credit card data, and the second node sends a request to a local API at [http://127.0.0.1:9080/filter](http://127.0.0.1:9080/filter) to filter out sensitive data from the credit card information. The second API will be just a serverless function using the [serverless-pre-function](https://apisix.apache.org/docs/apisix/plugins/serverless/) APISIX plugin.  It acts just as a backend service to modify the response from the first API.

### Step 3:  Create the second Route with the serverless plugin

Next, we configure a new route with the ID 2 that handles requests to `/filter` endpoint in the pipeline. It also enables [serverless-pre-function](https://apisix.apache.org/docs/apisix/plugins/serverless/) APISIX’s existing plugin where we specify a Lua function that should be executed by the plugin. This function simply retrieves the request body from the previous response, replaces the credit card number field, and leaves the rest of the response unchanged. Finally, it sets the current response body to the modified request body and sends an HTTP 200 response back to the client. You can modify this script to suit your needs, such as by using the decoded body to perform further processing or validation.

```bash
curl -X PUT 'http://127.0.0.1:9180/apisix/admin/routes/2' \
--header 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' \
--header 'Content-Type: application/json' \
--data-raw '
{
  "uri": "/filter",
  "plugins":{
    "serverless-pre-function": {
            "phase": "access",
            "functions": [
                "return function(conf, ctx)
                    local core = require(\"apisix.core\")
                    local cjson = require(\"cjson.safe\")

                    -- Get the request body
                    local body = core.request.get_body()
                    -- Decode the JSON body
                    local decoded_body = cjson.decode(body)

                    -- Hide the credit card number
                    decoded_body.credit_card_number = \"****-****-****-****\"
                    core.response.exit(200, decoded_body);
                end"
            ]
        }
    }
}'
```

### Step 3: Test setup

Now it is time to test the overall config. With the below curl command, we send an HTTP GET request to the endpoint **`http://127.0.0.1:9080/my-credit-cards`**.

```bash
curl http://127.0.0.1:9080/my-credit-cards
```

We have the corresponding route configured in the second step to use the **`pipeline-request`** plugin with two nodes, this request will trigger the pipeline to retrieve credit card information from the **`https://random-data-api.com/api/v2/credit_cards`** endpoint, filter out sensitive data using the **`http://127.0.0.1:9080/filter`** endpoint, and return the modified response to the client. See the output:

```json
{
   "uid":"a66239cd-960b-4e14-8d3c-a8940cedd907",
   "credit_card_expiry_date":"2025-05-10",
   "credit_card_type":"visa",
   "credit_card_number":"****-****-****-****",
   "id":2248
}
```

As you can see, it replaces the credit card number in the request body (Actually, it is the response from the first API call in the chain) with asterisks.
