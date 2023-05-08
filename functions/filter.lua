return function(conf, ctx) 
    local core = require(\"apisix.core\")
    local cjson = require(\"cjson.safe\")

    -- Get the request body
    local body = core.request.get_body()
    -- Decode the JSON body
    local decoded_body = cjson.decode(body)

    -- Hide the credit card number
    decoded_body.credit_card_number = \"****-****-****-****\"
    core.response.exit(200, decoded_body); 
end