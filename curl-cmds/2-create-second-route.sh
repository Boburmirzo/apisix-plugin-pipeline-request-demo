# Create a Route 2 (/filter) with serverless-pre-function plugin enabled.

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